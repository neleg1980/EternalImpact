# EternalImpact: Sustainable Charitable Impact Platform

## Overview
EternalImpact is a smart contract platform built on the Stacks blockchain that enables sustainable charitable giving through yield-bearing contributions and advanced legacy planning features. The platform allows contributors to make donations that generate yield, which can then be distributed to registered charitable organizations based on community support.

## Key Features

### Core Functionality
- **Yield-Bearing Contributions**: Contributions are pooled and generate simulated yield (5% for demonstration)
- **Community-Driven Support**: Contributors can vote for registered beneficiaries
- **Transparent Operations**: All transactions and yields are publicly verifiable
- **Secure Fund Management**: Built-in checks and balances for fund distribution

### Legacy Planning System
- **Multi-Tier Structure**: Supports up to 3 tiers of legacy planning
- **Customizable Parameters**: 
  - Configurable dormancy periods
  - Adjustable share percentages
  - Multiple successor assignments
- **Time-Based Alerts**: Automated notification system for successors

## Smart Contract Functions

### Core Functions
```clarity
(define-public (contribute))
(define-public (calculate-returns))
(define-public (allocate-returns (identifier (string-ascii 64))))
```

### Beneficiary Management
```clarity
(define-public (register-beneficiary (identifier (string-ascii 64)) (wallet principal)))
(define-public (support-beneficiary (identifier (string-ascii 64))))
```

### Legacy Planning
```clarity
(define-public (set-legacy-tier (tier uint) (dormancy-period uint) (successor principal) (share uint)))
(define-public (remove-legacy-tier (tier uint)))
```

### Monitoring and Alerts
```clarity
(define-public (check-and-alert-successors))
```

## Security Features

### Input Validation
- Comprehensive checks for beneficiary identifiers
- Validation of wallet addresses
- Range validation for all numerical inputs
- Prevention of duplicate voting/support

### Access Control
- Admin-only functions for critical operations
- Tiered access system for different operations
- Proper error handling with specific error codes

### State Management
- Atomic operations for state changes
- Activity tracking for security monitoring
- Safe mathematical operations

## Error Codes
- `error-unauthorized (err u100)`: Unauthorized access attempt
- `error-insufficient-balance (err u101)`: Insufficient funds for operation
- `error-beneficiary-not-found (err u102)`: Invalid beneficiary identifier
- `error-duplicate-support (err u103)`: Duplicate support attempt
- `error-transaction-failed (err u104)`: Transaction execution failure
- `error-invalid-legacy-tier (err u105)`: Invalid legacy tier specification
- `error-successor-not-found (err u106)`: Invalid successor address
- `error-not-successor (err u107)`: Unauthorized successor access
- `error-locked (err u108)`: Time-locked operation
- `error-invalid-input (err u109)`: Invalid input parameters

## Usage Examples

### Making a Contribution
```clarity
;; Contribute STX to the platform
(contract-call? .eternal-impact contribute)
```

### Setting Up Legacy Planning
```clarity
;; Set up a tier-1 legacy plan
(contract-call? .eternal-impact set-legacy-tier 
  u1                                  ;; tier
  u52560                             ;; dormancy period (≈1 year)
  'SP2ZNGJ85ENDY668R2QR0QHMG4PSQ6A5P69FHWADJ  ;; successor
  u50                                ;; 50% share
)
```

### Supporting a Beneficiary
```clarity
;; Support a registered beneficiary
(contract-call? .eternal-impact support-beneficiary "charity-name")
```

## Best Practices for Integration

1. **Input Validation**
   - Always validate inputs before making contract calls
   - Check returned error codes for proper error handling
   - Use provided read-only functions to verify state before transactions

2. **Legacy Planning**
   - Start with smaller dormancy periods for testing
   - Verify successor addresses carefully
   - Monitor alert systems regularly

3. **Transaction Monitoring**
   - Track transaction status through provided read-only functions
   - Implement proper error handling for failed transactions
   - Monitor yield generation and distribution events

## Contributing
Contributions to improve the contract are welcome. Please ensure:
- Comprehensive testing of new features
- Proper input validation
- Clear documentation of changes
- Adherence to existing security standards
