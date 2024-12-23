;; EternalImpact: A Sustainable Charitable Impact Platform
;; Constants
(define-constant admin-address tx-sender)
(define-constant error-unauthorized (err u100))
(define-constant error-insufficient-balance (err u101))
(define-constant error-beneficiary-not-found (err u102))
(define-constant error-duplicate-vote (err u103))
(define-constant error-transaction-failed (err u104))

;; Data Variables
(define-data-var vault-balance uint u0)
(define-data-var accrued-returns uint u0)
(define-map contributor-deposits principal uint)
(define-map beneficiaries {identifier: (string-ascii 64)} {wallet: principal, support-count: uint})
(define-map support-registry {beneficiary: (string-ascii 64), supporter: principal} bool)

;; Private Functions
(define-private (execute-payout (recipient principal) (amount uint))
  (match (as-contract (stx-transfer? amount tx-sender recipient))
    success (ok amount)
    error (err u1)
  )
)

;; Public Functions
(define-public (contribute)
  (let ((amount (stx-get-balance tx-sender)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set contributor-deposits tx-sender (+ (default-to u0 (map-get? contributor-deposits tx-sender)) amount))
    (var-set vault-balance (+ (var-get vault-balance) amount))
    (ok amount)
  )
)

(define-public (calculate-returns)
  (let (
    (new-returns (/ (* (var-get vault-balance) u5) u100)) ;; 5% return for simulation
  )
    (var-set accrued-returns (+ (var-get accrued-returns) new-returns))
    (ok new-returns)
  )
)

(define-public (allocate-returns (beneficiary (string-ascii 64)))
  (let (
    (beneficiary-data (unwrap! (map-get? beneficiaries {identifier: beneficiary}) (err error-beneficiary-not-found)))
    (return-amount (var-get accrued-returns))
  )
    (match (execute-payout (get wallet beneficiary-data) return-amount)
      success (begin
        (var-set accrued-returns u0)
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
    (ok true)
  )
)

(define-public (support-beneficiary (identifier (string-ascii 64)))
  (let (
    (previous-support (default-to false (map-get? support-registry {beneficiary: identifier, supporter: tx-sender})))
    (current-support-count (get support-count (unwrap! (map-get? beneficiaries {identifier: identifier}) error-beneficiary-not-found)))
  )
    (asserts! (not previous-support) error-duplicate-vote)
    (map-set support-registry {beneficiary: identifier, supporter: tx-sender} true)
    (map-set beneficiaries {identifier: identifier} 
      (merge (unwrap! (map-get? beneficiaries {identifier: identifier}) error-beneficiary-not-found)
             {support-count: (+ u1 current-support-count)}))
    (ok true)
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