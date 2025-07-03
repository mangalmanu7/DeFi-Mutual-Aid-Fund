(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_REQUEST_NOT_FOUND (err u103))
(define-constant ERR_REQUEST_ALREADY_PROCESSED (err u104))
(define-constant ERR_VOTING_PERIOD_ENDED (err u105))
(define-constant ERR_ALREADY_VOTED (err u106))
(define-constant ERR_MINIMUM_CONTRIBUTION_NOT_MET (err u107))
(define-constant ERR_INVALID_VOTING_PERIOD (err u108))

(define-constant MINIMUM_CONTRIBUTION u1000000)
(define-constant VOTING_PERIOD_BLOCKS u144)
(define-constant APPROVAL_THRESHOLD u60)

(define-constant ERR_NO_REWARDS_AVAILABLE (err u109))
(define-constant ERR_REWARD_ALREADY_CLAIMED (err u110))
(define-constant ERR_INSUFFICIENT_STREAK (err u111))
(define-constant REWARD_POOL_PERCENTAGE u5)
(define-constant MIN_STREAK_FOR_REWARD u3)
(define-constant BASE_REWARD_AMOUNT u500000)

(define-data-var reward-pool-balance uint u0)

(define-data-var fund-balance uint u0)
(define-data-var next-request-id uint u1)
(define-data-var total-contributors uint u0)

(define-map contributors principal uint)
(define-map contributor-voting-power principal uint)

(define-map aid-requests
  uint
  {
    requester: principal,
    amount: uint,
    reason: (string-ascii 500),
    created-at: uint,
    status: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    total-voting-power: uint
  }
)

(define-map request-votes
  { request-id: uint, voter: principal }
  { vote: bool, voting-power: uint }
)

(define-public (contribute (amount uint))
  (begin
    (asserts! (>= amount MINIMUM_CONTRIBUTION) ERR_MINIMUM_CONTRIBUTION_NOT_MET)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set fund-balance (+ (var-get fund-balance) amount))
    (let ((current-contribution (default-to u0 (map-get? contributors tx-sender))))
      (map-set contributors tx-sender (+ current-contribution amount))
      (map-set contributor-voting-power tx-sender (calculate-voting-power (+ current-contribution amount)))
      (if (is-eq current-contribution u0)
        (var-set total-contributors (+ (var-get total-contributors) u1))
        true
      )
    )
    (ok amount)
  )
)

(define-public (request-aid (amount uint) (reason (string-ascii 500)))
  (let ((request-id (var-get next-request-id)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount (var-get fund-balance)) ERR_INSUFFICIENT_FUNDS)
    (map-set aid-requests request-id {
      requester: tx-sender,
      amount: amount,
      reason: reason,
      created-at: stacks-block-height,
      status: "pending",
      votes-for: u0,
      votes-against: u0,
      total-voting-power: u0
    })
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

(define-public (vote-on-request (request-id uint) (support bool))
  (let (
    (request (unwrap! (map-get? aid-requests request-id) ERR_REQUEST_NOT_FOUND))
    (voter-power (default-to u0 (map-get? contributor-voting-power tx-sender)))
    (vote-key { request-id: request-id, voter: tx-sender })
  )
    (asserts! (> voter-power u0) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status request) "pending") ERR_REQUEST_ALREADY_PROCESSED)
    (asserts! (<= stacks-block-height (+ (get created-at request) VOTING_PERIOD_BLOCKS)) ERR_VOTING_PERIOD_ENDED)
    (asserts! (is-none (map-get? request-votes vote-key)) ERR_ALREADY_VOTED)
    
    (map-set request-votes vote-key { vote: support, voting-power: voter-power })
    
    (let (
      (new-votes-for (if support (+ (get votes-for request) voter-power) (get votes-for request)))
      (new-votes-against (if support (get votes-against request) (+ (get votes-against request) voter-power)))
      (new-total-power (+ (get total-voting-power request) voter-power))
    )
      (map-set aid-requests request-id (merge request {
        votes-for: new-votes-for,
        votes-against: new-votes-against,
        total-voting-power: new-total-power
      }))
    )
    (ok true)
  )
)

(define-public (process-request (request-id uint))
  (let (
    (request (unwrap! (map-get? aid-requests request-id) ERR_REQUEST_NOT_FOUND))
  )
    (asserts! (is-eq (get status request) "pending") ERR_REQUEST_ALREADY_PROCESSED)
    (asserts! (> stacks-block-height (+ (get created-at request) VOTING_PERIOD_BLOCKS)) ERR_VOTING_PERIOD_ENDED)
    
    (let (
      (approval-rate (if (> (get total-voting-power request) u0)
                      (/ (* (get votes-for request) u100) (get total-voting-power request))
                      u0))
      (approved (>= approval-rate APPROVAL_THRESHOLD))
    )
      (if approved
        (begin
          (try! (as-contract (stx-transfer? (get amount request) tx-sender (get requester request))))
          (var-set fund-balance (- (var-get fund-balance) (get amount request)))
          (map-set aid-requests request-id (merge request { status: "approved" }))
          (ok "approved")
        )
        (begin
          (map-set aid-requests request-id (merge request { status: "rejected" }))
          (ok "rejected")
        )
      )
    )
  )
)

(define-public (emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (let ((balance (var-get fund-balance)))
      (try! (as-contract (stx-transfer? balance tx-sender CONTRACT_OWNER)))
      (var-set fund-balance u0)
      (ok balance)
    )
  )
)

(define-read-only (get-fund-balance)
  (var-get fund-balance)
)

(define-read-only (get-contributor-info (contributor principal))
  {
    contribution: (default-to u0 (map-get? contributors contributor)),
    voting-power: (default-to u0 (map-get? contributor-voting-power contributor))
  }
)

(define-read-only (get-request-details (request-id uint))
  (map-get? aid-requests request-id)
)

(define-read-only (get-vote-details (request-id uint) (voter principal))
  (map-get? request-votes { request-id: request-id, voter: voter })
)

(define-read-only (get-fund-stats)
  {
    total-balance: (var-get fund-balance),
    total-contributors: (var-get total-contributors),
    next-request-id: (var-get next-request-id)
  }
)

(define-read-only (calculate-voting-power (contribution uint))
  (if (>= contribution u10000000)
    u100
    (if (>= contribution u5000000)
      u50
      (if (>= contribution u1000000)
        u10
        u1
      )
    )
  )
)

(define-read-only (get-request-approval-rate (request-id uint))
  (match (map-get? aid-requests request-id)
    request (if (> (get total-voting-power request) u0)
              (/ (* (get votes-for request) u100) (get total-voting-power request))
              u0)
    u0
  )
)

(define-read-only (is-voting-active (request-id uint))
  (match (map-get? aid-requests request-id)
    request (and 
              (is-eq (get status request) "pending")
              (<= stacks-block-height (+ (get created-at request) VOTING_PERIOD_BLOCKS)))
    false
  )
)

(define-read-only (get-time-remaining (request-id uint))
  (match (map-get? aid-requests request-id)
    request (let ((end-block (+ (get created-at request) VOTING_PERIOD_BLOCKS)))
              (if (> end-block stacks-block-height)
                (- end-block stacks-block-height)
                u0))
    u0
  )
)

(define-map contribution-streaks principal uint)
(define-map last-contribution-block principal uint)
(define-map reward-claims principal uint)

(define-public (contribute-with-rewards (amount uint))
  (begin
    (try! (contribute amount))
    (let (
      (current-block stacks-block-height)
      (last-block (default-to u0 (map-get? last-contribution-block tx-sender)))
      (current-streak (default-to u0 (map-get? contribution-streaks tx-sender)))
      (reward-amount (/ (* amount REWARD_POOL_PERCENTAGE) u100))
    )
      (var-set reward-pool-balance (+ (var-get reward-pool-balance) reward-amount))
      (if (and (> last-block u0) (<= (- current-block last-block) u1008))
        (map-set contribution-streaks tx-sender (+ current-streak u1))
        (map-set contribution-streaks tx-sender u1)
      )
      (map-set last-contribution-block tx-sender current-block)
      (ok amount)
    )
  )
)

(define-public (claim-streak-reward)
  (let (
    (streak (default-to u0 (map-get? contribution-streaks tx-sender)))
    (last-claim (default-to u0 (map-get? reward-claims tx-sender)))
  )
    (asserts! (>= streak MIN_STREAK_FOR_REWARD) ERR_INSUFFICIENT_STREAK)
    (asserts! (< last-claim stacks-block-height) ERR_REWARD_ALREADY_CLAIMED)
    (let (
      (reward-multiplier (/ streak u3))
      (reward-amount (* BASE_REWARD_AMOUNT reward-multiplier))
      (available-rewards (var-get reward-pool-balance))
    )
      (asserts! (>= available-rewards reward-amount) ERR_NO_REWARDS_AVAILABLE)
      (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
      (var-set reward-pool-balance (- available-rewards reward-amount))
      (map-set reward-claims tx-sender stacks-block-height)
      (ok reward-amount)
    )
  )
)

(define-read-only (get-contributor-streak (contributor principal))
  (default-to u0 (map-get? contribution-streaks contributor))
)

(define-read-only (get-reward-pool-balance)
  (var-get reward-pool-balance)
)

(define-read-only (calculate-potential-reward (contributor principal))
  (let (
    (streak (default-to u0 (map-get? contribution-streaks contributor)))
    (reward-multiplier (/ streak u3))
  )
    (if (>= streak MIN_STREAK_FOR_REWARD)
      (* BASE_REWARD_AMOUNT reward-multiplier)
      u0
    )
  )
)

(define-read-only (get-reward-status (contributor principal))
  {
    streak: (get-contributor-streak contributor),
    potential-reward: (calculate-potential-reward contributor),
    last-claim: (default-to u0 (map-get? reward-claims contributor)),
    can-claim: (>= (get-contributor-streak contributor) MIN_STREAK_FOR_REWARD)
  }
)