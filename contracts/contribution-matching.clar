(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_AMOUNT (err u201))
(define-constant ERR_MATCHING_POOL_DEPLETED (err u202))
(define-constant ERR_MATCH_RATIO_INVALID (err u203))
(define-constant ERR_MINIMUM_NOT_MET (err u204))
(define-constant ERR_PLEDGE_NOT_FOUND (err u205))

(define-constant MIN_CONTRIBUTION u1000000)
(define-constant MAX_MATCH_RATIO u200)

(define-data-var matching-pool-balance uint u0)
(define-data-var total-matched-amount uint u0)
(define-data-var next-pledge-id uint u1)

(define-map matching-pledges
  uint
  {
    pledger: principal,
    pledge-amount: uint,
    remaining-balance: uint,
    match-ratio: uint,
    created-at: uint,
    active: bool
  }
)

(define-map contributor-matched-totals principal uint)
(define-map pledger-stats principal { total-pledged: uint, total-matched: uint })

(define-public (create-matching-pledge (amount uint) (match-ratio uint))
  (let ((pledge-id (var-get next-pledge-id)))
    (asserts! (>= amount MIN_CONTRIBUTION) ERR_MINIMUM_NOT_MET)
    (asserts! (and (> match-ratio u0) (<= match-ratio MAX_MATCH_RATIO)) ERR_MATCH_RATIO_INVALID)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set matching-pledges pledge-id {
      pledger: tx-sender,
      pledge-amount: amount,
      remaining-balance: amount,
      match-ratio: match-ratio,
      created-at: stacks-block-height,
      active: true
    })
    (var-set matching-pool-balance (+ (var-get matching-pool-balance) amount))
    (let ((current-stats (default-to { total-pledged: u0, total-matched: u0 } 
                          (map-get? pledger-stats tx-sender))))
      (map-set pledger-stats tx-sender {
        total-pledged: (+ (get total-pledged current-stats) amount),
        total-matched: (get total-matched current-stats)
      })
    )
    (var-set next-pledge-id (+ pledge-id u1))
    (ok pledge-id)
  )
)

(define-public (contribute-with-match (contribution-amount uint) (pledge-id uint))
  (let (
    (pledge (unwrap! (map-get? matching-pledges pledge-id) ERR_PLEDGE_NOT_FOUND))
    (match-amount (/ (* contribution-amount (get match-ratio pledge)) u100))
    (available-match (get remaining-balance pledge))
    (actual-match (if (<= match-amount available-match) match-amount available-match))
  )
    (asserts! (>= contribution-amount MIN_CONTRIBUTION) ERR_MINIMUM_NOT_MET)
    (asserts! (get active pledge) ERR_UNAUTHORIZED)
    (asserts! (> actual-match u0) ERR_MATCHING_POOL_DEPLETED)
    (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
    (map-set matching-pledges pledge-id (merge pledge {
      remaining-balance: (- available-match actual-match),
      active: (> (- available-match actual-match) u0)
    }))
    (var-set matching-pool-balance (- (var-get matching-pool-balance) actual-match))
    (var-set total-matched-amount (+ (var-get total-matched-amount) actual-match))
    (map-set contributor-matched-totals tx-sender 
      (+ (default-to u0 (map-get? contributor-matched-totals tx-sender)) actual-match))
    (ok { contributed: contribution-amount, matched: actual-match, total: (+ contribution-amount actual-match) })
  )
)

(define-read-only (get-matching-pool-balance)
  (var-get matching-pool-balance)
)

(define-read-only (get-pledge-details (pledge-id uint))
  (map-get? matching-pledges pledge-id)
)

(define-read-only (get-contributor-match-total (contributor principal))
  (default-to u0 (map-get? contributor-matched-totals contributor))
)

(define-read-only (get-pledger-stats (pledger principal))
  (default-to { total-pledged: u0, total-matched: u0 } (map-get? pledger-stats pledger))
)

(define-read-only (get-matching-stats)
  {
    total-pool: (var-get matching-pool-balance),
    total-matched: (var-get total-matched-amount),
    next-pledge-id: (var-get next-pledge-id)
  }
)