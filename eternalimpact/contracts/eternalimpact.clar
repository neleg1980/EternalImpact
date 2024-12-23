;; EternalImpact: A Sustainable Charitable Impact Platform with Legacy Planning and Time-Based Alerts

;; Constants
(define-constant admin-address tx-sender)
(define-constant error-unauthorized (err u100))
(define-constant error-insufficient-balance (err u101))
(define-constant error-beneficiary-not-found (err u102))
(define-constant error-duplicate-support (err u103))
(define-constant error-transaction-failed (err u104))
(define-constant error-invalid-legacy-tier (err u105))
(define-constant error-successor-not-found (err u106))
(define-constant error-not-successor (err u107))
(define-constant error-locked (err u108))

;; Data Variables
(define-data-var vault-balance uint u0)
(define-data-var accrued-returns uint u0)
(define-data-var last-interaction-block uint u0)
(define-map contributor-deposits principal uint)
(define-map beneficiaries {identifier: (string-ascii 64)} {wallet: principal, support-count: uint})
(define-map support-registry {beneficiary: (string-ascii 64), supporter: principal} bool)
(define-map legacy-tiers 
  {account: principal, tier: uint} 
  {dormancy-period: uint, successor: principal, share: uint, last-alert: uint}
)
(define-map successor-alerts 
  {successor: principal, account: principal} 
  {tier: uint, activation-time: uint, alerted: bool}
)

;; Private Functions
(define-private (execute-payout (recipient principal) (amount uint))
  (match (as-contract (stx-transfer? amount tx-sender recipient))
    success (ok amount)
    error (err error-transaction-failed)
  )
)

(define-private (record-interaction)
  (var-set last-interaction-block block-height)
)

;; Public Functions
(define-public (contribute)
  (let ((amount (stx-get-balance tx-sender)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set contributor-deposits tx-sender (+ (default-to u0 (map-get? contributor-deposits tx-sender)) amount))
    (var-set vault-balance (+ (var-get vault-balance) amount))
    (record-interaction)
    (ok amount)
  )
)

(define-public (calculate-returns)
  (let (
    (new-returns (/ (* (var-get vault-balance) u5) u100)) ;; 5% return for simulation
  )
    (var-set accrued-returns (+ (var-get accrued-returns) new-returns))
    (record-interaction)
    (ok new-returns)
  )
)

(define-public (allocate-returns (identifier (string-ascii 64)))
  (let (
    (beneficiary-data (unwrap! (map-get? beneficiaries {identifier: identifier}) (err error-beneficiary-not-found)))
    (return-amount (var-get accrued-returns))
  )
    (match (execute-payout (get wallet beneficiary-data) return-amount)
      success (begin
        (var-set accrued-returns u0)
        (record-interaction)
        (ok return-amount)
      )
      error (err error-transaction-failed)
    )
  )
)

(define-read-only (check-status)
  (ok {
    vault-total: (var-get vault-balance),
    pending-returns: (var-get accrued-returns)
  })
)

(define-public (register-beneficiary (identifier (string-ascii 64)) (wallet principal))
  (begin
    (asserts! (is-eq tx-sender admin-address) error-unauthorized)
    (map-set beneficiaries {identifier: identifier} {wallet: wallet, support-count: u0})
    (record-interaction)
    (ok true)
  )
)

(define-public (support-beneficiary (identifier (string-ascii 64)))
  (let (
    (previous-support (default-to false (map-get? support-registry {beneficiary: identifier, supporter: tx-sender})))
    (current-support-count (get support-count (unwrap! (map-get? beneficiaries {identifier: identifier}) error-beneficiary-not-found)))
  )
    (asserts! (not previous-support) error-duplicate-support)
    (map-set support-registry {beneficiary: identifier, supporter: tx-sender} true)
    (map-set beneficiaries {identifier: identifier} 
      (merge (unwrap! (map-get? beneficiaries {identifier: identifier}) error-beneficiary-not-found)
             {support-count: (+ u1 current-support-count)}))
    (record-interaction)
    (ok true)
  )
)

;; Legacy Tier Management
(define-public (set-legacy-tier (tier uint) (dormancy-period uint) (successor principal) (share uint))
  (begin
    (asserts! (and (>= tier u1) (<= tier u3)) error-invalid-legacy-tier)
    (asserts! (<= share u100) error-invalid-legacy-tier)
    (map-set legacy-tiers {account: tx-sender, tier: tier} 
      {dormancy-period: dormancy-period, successor: successor, share: share, last-alert: u0})
    (record-interaction)
    (ok true)
  )
)

(define-public (remove-legacy-tier (tier uint))
  (begin
    (asserts! (and (>= tier u1) (<= tier u3)) error-invalid-legacy-tier)
    (map-delete legacy-tiers {account: tx-sender, tier: tier})
    (record-interaction)
    (ok true)
  )
)

(define-read-only (get-legacy-tier (account principal) (tier uint))
  (match (map-get? legacy-tiers {account: account, tier: tier})
    tier-info (ok tier-info)
    (err error-successor-not-found)
  )
)

(define-private (execute-legacy-transfer (account principal) (successor principal) (share uint) (total-balance uint))
  (let (
    (transfer-amount (/ (* total-balance share) u100))
  )
    (match (as-contract (stx-transfer? transfer-amount tx-sender successor))
      success (begin
        (var-set vault-balance (- total-balance transfer-amount))
        (map-delete contributor-deposits account)
        (map-delete legacy-tiers {account: account, tier: u1})
        (map-delete legacy-tiers {account: account, tier: u2})
        (map-delete legacy-tiers {account: account, tier: u3})
        (map-delete successor-alerts {successor: successor, account: account})
        (ok transfer-amount)
      )
      error (err error-transaction-failed)
    )
  )
)

;; Time-Based Alert System
(define-public (check-and-alert-successors)
  (let (
    (current-block block-height)
    (last-activity (var-get last-interaction-block))
  )
    (map-set successor-alerts 
      {successor: tx-sender, account: admin-address}
      (merge 
        (default-to 
          {tier: u0, activation-time: u0, alerted: false}
          (map-get? successor-alerts {successor: tx-sender, account: admin-address})
        )
        {
          tier: (get-highest-qualified-tier tx-sender admin-address current-block last-activity),
          activation-time: (+ last-activity (get-dormancy-period tx-sender admin-address)),
          alerted: true
        }
      )
    )
    (ok true)
  )
)

(define-private (get-highest-qualified-tier (successor principal) (account principal) (current-block uint) (last-activity uint))
  (let (
    (tier-1 (default-to {dormancy-period: u0, successor: 'SP000000000000000000002Q6VF78, share: u0, last-alert: u0} 
              (map-get? legacy-tiers {account: account, tier: u1})))
    (tier-2 (default-to {dormancy-period: u0, successor: 'SP000000000000000000002Q6VF78, share: u0, last-alert: u0} 
              (map-get? legacy-tiers {account: account, tier: u2})))
    (tier-3 (default-to {dormancy-period: u0, successor: 'SP000000000000000000002Q6VF78, share: u0, last-alert: u0} 
              (map-get? legacy-tiers {account: account, tier: u3})))
  )
    (if (and (is-eq successor (get successor tier-3)) (>= (- current-block last-activity) (get dormancy-period tier-3)))
      u3
      (if (and (is-eq successor (get successor tier-2)) (>= (- current-block last-activity) (get dormancy-period tier-2)))
        u2
        (if (and (is-eq successor (get successor tier-1)) (>= (- current-block last-activity) (get dormancy-period tier-1)))
          u1
          u0
        )
      )
    )
  )
)

(define-private (get-dormancy-period (successor principal) (account principal))
  (let (
    (tier-1 (default-to {dormancy-period: u0, successor: 'SP000000000000000000002Q6VF78, share: u0, last-alert: u0} 
              (map-get? legacy-tiers {account: account, tier: u1})))
    (tier-2 (default-to {dormancy-period: u0, successor: 'SP000000000000000000002Q6VF78, share: u0, last-alert: u0} 
              (map-get? legacy-tiers {account: account, tier: u2})))
    (tier-3 (default-to {dormancy-period: u0, successor: 'SP000000000000000000002Q6VF78, share: u0, last-alert: u0} 
              (map-get? legacy-tiers {account: account, tier: u3})))
  )
    (if (is-eq successor (get successor tier-3))
      (get dormancy-period tier-3)
      (if (is-eq successor (get successor tier-2))
        (get dormancy-period tier-2)
        (if (is-eq successor (get successor tier-1))
          (get dormancy-period tier-1)
          u0
        )
      )
    )
  )
)

;; Read-only functions for transparency
(define-read-only (get-contribution (contributor principal))
  (ok (default-to u0 (map-get? contributor-deposits contributor)))
)

(define-read-only (get-beneficiary-data (identifier (string-ascii 64)))
  (ok (unwrap! (map-get? beneficiaries {identifier: identifier}) error-beneficiary-not-found))
)

(define-read-only (get-total-contributions)
  (ok (var-get vault-balance))
)

(define-read-only (get-pending-returns)
  (ok (var-get accrued-returns))
)

(define-read-only (get-last-activity)
  (ok (var-get last-interaction-block))
)

(define-read-only (get-successor-alert (successor principal) (account principal))
  (ok (unwrap! (map-get? successor-alerts {successor: successor, account: account}) error-not-successor))
)