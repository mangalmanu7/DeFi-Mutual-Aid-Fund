(define-constant ERR_PLEDGE_NOT_FOUND (err u300))
(define-constant ERR_UNAUTHORIZED (err u301))
(define-constant ERR_NOT_EXPIRED (err u302))
(define-constant ERR_INVALID_DURATION (err u303))
(define-constant ERR_PLEDGE_INACTIVE (err u304))
(define-constant ERR_NO_BALANCE_TO_WITHDRAW (err u305))

(define-constant MIN_EXPIRATION_BLOCKS u1008)
(define-constant MAX_EXPIRATION_BLOCKS u52560)
(define-constant MIN_CONTRIBUTION u1000000)

(define-data-var next-expiring-pledge-id uint u1)

(define-map expiring-pledges
  uint
  {
    pledger: principal,
    amount: uint,
    remaining-balance: uint,
    expires-at: uint,
    created-at: uint,
    active: bool
  }
)

(define-map pledger-total-withdrawn principal uint)

(define-public (create-expiring-pledge (amount uint) (duration-blocks uint))
  (let ((pledge-id (var-get next-expiring-pledge-id)))
    (asserts! (>= amount MIN_CONTRIBUTION) ERR_INVALID_DURATION)
    (asserts! (and (>= duration-blocks MIN_EXPIRATION_BLOCKS) 
                   (<= duration-blocks MAX_EXPIRATION_BLOCKS)) 
              ERR_INVALID_DURATION)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set expiring-pledges pledge-id {
      pledger: tx-sender,
      amount: amount,
      remaining-balance: amount,
      expires-at: (+ stacks-block-height duration-blocks),
      created-at: stacks-block-height,
      active: true
    })
    (var-set next-expiring-pledge-id (+ pledge-id u1))
    (ok pledge-id)
  )
)

(define-public (withdraw-expired-pledge (pledge-id uint))
  (let ((pledge (unwrap! (map-get? expiring-pledges pledge-id) ERR_PLEDGE_NOT_FOUND)))
    (asserts! (is-eq (get pledger pledge) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> stacks-block-height (get expires-at pledge)) ERR_NOT_EXPIRED)
    (asserts! (> (get remaining-balance pledge) u0) ERR_NO_BALANCE_TO_WITHDRAW)
    (let ((withdrawal-amount (get remaining-balance pledge)))
      (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get pledger pledge))))
      (map-set expiring-pledges pledge-id (merge pledge {
        remaining-balance: u0,
        active: false
      }))
      (map-set pledger-total-withdrawn tx-sender 
        (+ (default-to u0 (map-get? pledger-total-withdrawn tx-sender)) withdrawal-amount))
      (ok withdrawal-amount)
    )
  )
)

(define-public (renew-pledge (pledge-id uint) (additional-blocks uint))
  (let ((pledge (unwrap! (map-get? expiring-pledges pledge-id) ERR_PLEDGE_NOT_FOUND)))
    (asserts! (is-eq (get pledger pledge) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get active pledge) ERR_PLEDGE_INACTIVE)
    (asserts! (and (>= additional-blocks MIN_EXPIRATION_BLOCKS)
                   (<= (+ (get expires-at pledge) additional-blocks) 
                       (+ stacks-block-height MAX_EXPIRATION_BLOCKS)))
              ERR_INVALID_DURATION)
    (map-set expiring-pledges pledge-id (merge pledge {
      expires-at: (+ (get expires-at pledge) additional-blocks)
    }))
    (ok (+ (get expires-at pledge) additional-blocks))
  )
)

(define-read-only (get-pledge-details (pledge-id uint))
  (map-get? expiring-pledges pledge-id)
)

(define-read-only (is-pledge-expired (pledge-id uint))
  (match (map-get? expiring-pledges pledge-id)
    pledge (> stacks-block-height (get expires-at pledge))
    false
  )
)

(define-read-only (get-blocks-until-expiration (pledge-id uint))
  (match (map-get? expiring-pledges pledge-id)
    pledge (if (> (get expires-at pledge) stacks-block-height)
             (- (get expires-at pledge) stacks-block-height)
             u0)
    u0
  )
)

(define-read-only (get-pledger-withdrawal-total (pledger principal))
  (default-to u0 (map-get? pledger-total-withdrawn pledger))
)

(define-read-only (get-expiration-stats)
  {
    total-pledges: (var-get next-expiring-pledge-id),
    min-duration: MIN_EXPIRATION_BLOCKS,
    max-duration: MAX_EXPIRATION_BLOCKS
  }
)
