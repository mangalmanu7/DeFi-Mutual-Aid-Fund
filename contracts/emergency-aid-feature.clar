(define-constant ERR_EMERGENCY_INSUFFICIENT_FUNDS (err u115))
(define-constant ERR_EMERGENCY_NOT_ELIGIBLE (err u116))
(define-constant ERR_EMERGENCY_LIMIT_EXCEEDED (err u117))
(define-constant ERR_EMERGENCY_COOLDOWN_ACTIVE (err u118))

(define-constant EMERGENCY_CONTRIBUTION_THRESHOLD u5000000)
(define-constant MINIMUM_CONTRIBUTION u1000000)
(define-constant ERR_MINIMUM_CONTRIBUTION_NOT_MET (err u107))
(define-constant EMERGENCY_MAX_CLAIM_AMOUNT u2000000)
(define-constant EMERGENCY_COOLDOWN_BLOCKS u2016)

(define-data-var emergency-pool-balance uint u0)
(define-map emergency-contributors principal uint)
(define-map emergency-claims principal uint)
(define-map last-emergency-claim principal uint)

(define-public (contribute-to-emergency (amount uint))
  (begin
    (asserts! (>= amount MINIMUM_CONTRIBUTION) ERR_MINIMUM_CONTRIBUTION_NOT_MET)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set emergency-pool-balance (+ (var-get emergency-pool-balance) amount))
    (let ((current-emergency-contribution (default-to u0 (map-get? emergency-contributors tx-sender))))
      (map-set emergency-contributors tx-sender (+ current-emergency-contribution amount))
      (ok amount)
    )
  )
)

(define-public (request-emergency-aid (amount uint) (reason (string-ascii 500)))
  (let (
    (contributor-total (default-to u0 (map-get? emergency-contributors tx-sender)))
    (emergency-total (default-to u0 (map-get? emergency-contributors tx-sender)))
    (total-contribution (+ contributor-total emergency-total))
    (last-claim-block (default-to u0 (map-get? last-emergency-claim tx-sender)))
  )
    (asserts! (>= total-contribution EMERGENCY_CONTRIBUTION_THRESHOLD) ERR_EMERGENCY_NOT_ELIGIBLE)
    (asserts! (<= amount EMERGENCY_MAX_CLAIM_AMOUNT) ERR_EMERGENCY_LIMIT_EXCEEDED)
    (asserts! (<= amount (var-get emergency-pool-balance)) ERR_EMERGENCY_INSUFFICIENT_FUNDS)
    (asserts! (> stacks-block-height (+ last-claim-block EMERGENCY_COOLDOWN_BLOCKS)) ERR_EMERGENCY_COOLDOWN_ACTIVE)
    
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (var-set emergency-pool-balance (- (var-get emergency-pool-balance) amount))
    (map-set emergency-claims tx-sender (+ (default-to u0 (map-get? emergency-claims tx-sender)) amount))
    (map-set last-emergency-claim tx-sender stacks-block-height)
    (ok amount)
  )
)

(define-read-only (get-emergency-pool-balance)
  (var-get emergency-pool-balance)
)

(define-read-only (get-emergency-contributor-info (contributor principal))
  {
    emergency-contribution: (default-to u0 (map-get? emergency-contributors contributor)),
    total-emergency-claimed: (default-to u0 (map-get? emergency-claims contributor)),
    last-claim-block: (default-to u0 (map-get? last-emergency-claim contributor))
  }
)

(define-read-only (check-emergency-eligibility (contributor principal))
  (let (
    (contributor-total (default-to u0 (map-get? emergency-contributors contributor)))
    (emergency-total (default-to u0 (map-get? emergency-contributors contributor)))
    (total-contribution (+ contributor-total emergency-total))
    (last-claim-block (default-to u0 (map-get? last-emergency-claim contributor)))
  )
    {
      eligible: (>= total-contribution EMERGENCY_CONTRIBUTION_THRESHOLD),
      max-claim-amount: EMERGENCY_MAX_CLAIM_AMOUNT,
      cooldown-remaining: (if (> (+ last-claim-block EMERGENCY_COOLDOWN_BLOCKS) stacks-block-height)
                            (- (+ last-claim-block EMERGENCY_COOLDOWN_BLOCKS) stacks-block-height)
                            u0),
      available-pool: (var-get emergency-pool-balance)
    }
  )
)

(define-read-only (get-emergency-stats)
  {
    total-emergency-balance: (var-get emergency-pool-balance),
    contribution-threshold: EMERGENCY_CONTRIBUTION_THRESHOLD,
    max-claim-amount: EMERGENCY_MAX_CLAIM_AMOUNT,
    cooldown-period: EMERGENCY_COOLDOWN_BLOCKS
  }
)
