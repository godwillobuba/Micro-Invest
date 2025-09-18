;; Decentralized Micro-Investment Platform Smart Contract
;; This contract enables users to create investment projects and allows others to make micro-investments

;; CONSTANTS
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-PROJECT-CLOSED (err u104))
(define-constant ERR-PROJECT-NOT-FUNDED (err u105))
(define-constant ERR-ALREADY-WITHDRAWN (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))
(define-constant ERR-DEADLINE-PASSED (err u108))
(define-constant ERR-DEADLINE-NOT-REACHED (err u109))
(define-constant ERR-ZERO-AMOUNT (err u110))
(define-constant ERR-INVALID-INPUT (err u111))
(define-constant ERR-INVALID-PROJECT-ID (err u112))

;; Platform fee percentage (in basis points, e.g., 250 = 2.5%)
(define-constant PLATFORM-FEE u250)

;; Input validation constants
(define-constant MAX-PROJECT-ID u1000000)
(define-constant MIN-TITLE-LENGTH u1)
(define-constant MIN-DESCRIPTION-LENGTH u10)

;; DATA VARIABLES
(define-data-var next-project-id uint u1)
(define-data-var platform-treasury uint u0)

;; DATA MAPS

;; User profiles
(define-map users 
  principal 
  {
    total-invested: uint,
    total-projects: uint,
    reputation-score: uint,
    is-verified: bool
  }
)

;; Investment projects
(define-map projects 
  uint 
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    deadline: uint,
    is-active: bool,
    is-funded: bool,
    returns-distributed: bool,
    min-investment: uint,
    expected-return-rate: uint,
    total-investors: uint
  }
)

;; Individual investments in projects
(define-map investments 
  {investor: principal, project-id: uint}
  {
    amount: uint,
    timestamp: uint,
    returns-claimed: bool
  }
)

;; Track all investors for a project
(define-map project-investors
  {project-id: uint, investor-index: uint}
  principal
)

;; Track investor count per project for easier iteration
(define-map investor-counts
  uint
  uint
)

;; VALIDATION HELPER FUNCTIONS

;; Validate string is not empty and within bounds
(define-private (is-valid-string (input (string-ascii 500)) (min-len uint))
  (and 
    (>= (len input) min-len)
    (> (len input) u0)
  )
)

;; Validate project ID is within reasonable bounds
(define-private (is-valid-project-id (project-id uint))
  (and 
    (> project-id u0)
    (<= project-id MAX-PROJECT-ID)
  )
)

;; Validate project exists and get it safely
(define-private (get-validated-project (project-id uint))
  (begin
    (asserts! (is-valid-project-id project-id) ERR-INVALID-PROJECT-ID)
    (ok (unwrap! (map-get? projects project-id) ERR-NOT-FOUND))
  )
)

;; READ-ONLY FUNCTIONS

;; Get user profile
(define-read-only (get-user (user principal))
  (default-to 
    {
      total-invested: u0,
      total-projects: u0,
      reputation-score: u0,
      is-verified: false
    }
    (map-get? users user)
  )
)

;; Get project details with validation
(define-read-only (get-project (project-id uint))
  (if (is-valid-project-id project-id)
    (map-get? projects project-id)
    none
  )
)

;; Get investment details
(define-read-only (get-investment (investor principal) (project-id uint))
  (if (is-valid-project-id project-id)
    (map-get? investments {investor: investor, project-id: project-id})
    none
  )
)

;; Get platform treasury balance
(define-read-only (get-platform-treasury)
  (var-get platform-treasury)
)

;; Get next project ID
(define-read-only (get-next-project-id)
  (var-get next-project-id)
)

;; Check if project funding goal is reached
(define-read-only (is-project-funded (project-id uint))
  (match (get-project project-id)
    project (>= (get current-funding project) (get funding-goal project))
    false
  )
)

;; Calculate potential returns for an investment
(define-read-only (calculate-returns (project-id uint) (investment-amount uint))
  (match (get-project project-id)
    project 
      (let 
        (
          (return-rate (get expected-return-rate project))
          (base-returns (/ (* investment-amount return-rate) u10000))
        )
        (ok base-returns)
      )
    (err ERR-NOT-FOUND)
  )
)

;; Get investor at specific index for a project
(define-read-only (get-project-investor (project-id uint) (investor-index uint))
  (if (is-valid-project-id project-id)
    (map-get? project-investors {project-id: project-id, investor-index: investor-index})
    none
  )
)

;; Get total number of investors for a project
(define-read-only (get-investor-count (project-id uint))
  (if (is-valid-project-id project-id)
    (default-to u0 (map-get? investor-counts project-id))
    u0
  )
)

;; PUBLIC FUNCTIONS

;; Register or update user profile
(define-public (register-user)
  (let 
    (
      (current-user (get-user tx-sender))
    )
    (ok (map-set users tx-sender
      (merge current-user {reputation-score: (+ (get reputation-score current-user) u10)})
    ))
  )
)

;; Create a new investment project with enhanced validation
(define-public (create-project 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (funding-goal uint)
  (deadline uint)
  (min-investment uint)
  (expected-return-rate uint)
)
  (let 
    (
      (project-id (var-get next-project-id))
      (current-user (get-user tx-sender))
    )
    ;; Enhanced input validation
    (asserts! (is-valid-string title MIN-TITLE-LENGTH) ERR-INVALID-INPUT)
    (asserts! (is-valid-string description MIN-DESCRIPTION-LENGTH) ERR-INVALID-INPUT)
    (asserts! (> funding-goal u0) ERR-INVALID-AMOUNT)
    (asserts! (> deadline block-height) ERR-DEADLINE-PASSED)
    (asserts! (> min-investment u0) ERR-ZERO-AMOUNT)
    (asserts! (<= expected-return-rate u10000) ERR-INVALID-AMOUNT) ;; Max 100% return
    (asserts! (< project-id MAX-PROJECT-ID) ERR-INVALID-PROJECT-ID)
    
    ;; Create project with validated inputs
    (map-set projects project-id
      {
        creator: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        deadline: deadline,
        is-active: true,
        is-funded: false,
        returns-distributed: false,
        min-investment: min-investment,
        expected-return-rate: expected-return-rate,
        total-investors: u0
      }
    )
    
    ;; Initialize investor count
    (map-set investor-counts project-id u0)
    
    ;; Update user profile
    (map-set users tx-sender
      (merge current-user {
        total-projects: (+ (get total-projects current-user) u1),
        reputation-score: (+ (get reputation-score current-user) u20)
      })
    )
    
    ;; Increment next project ID
    (var-set next-project-id (+ project-id u1))
    
    (ok project-id)
  )
)

;; Invest in a project
(define-public (invest-in-project (project-id uint) (amount uint))
  (let 
    (
      (project (try! (get-validated-project project-id)))
      (existing-investment (map-get? investments {investor: tx-sender, project-id: project-id}))
      (current-user (get-user tx-sender))
      (platform-fee-amount (/ (* amount PLATFORM-FEE) u10000))
      (investment-amount (- amount platform-fee-amount))
    )
    (asserts! (get is-active project) ERR-PROJECT-CLOSED)
    (asserts! (< block-height (get deadline project)) ERR-DEADLINE-PASSED)
    (asserts! (>= amount (get min-investment project)) ERR-INVALID-AMOUNT)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer STX from investor
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update platform treasury
    (var-set platform-treasury (+ (var-get platform-treasury) platform-fee-amount))
    
    ;; Handle investment record
    (match existing-investment
      existing
        ;; Update existing investment
        (map-set investments {investor: tx-sender, project-id: project-id}
          {
            amount: (+ (get amount existing) investment-amount),
            timestamp: block-height,
            returns-claimed: false
          }
        )
      ;; Create new investment record and add to investor list
      (begin
        (map-set investments {investor: tx-sender, project-id: project-id}
          {
            amount: investment-amount,
            timestamp: block-height,
            returns-claimed: false
          }
        )
        ;; Add investor to project investors list
        (let ((investor-count (get-investor-count project-id)))
          (map-set project-investors 
            {project-id: project-id, investor-index: investor-count}
            tx-sender
          )
          (map-set investor-counts project-id (+ investor-count u1))
        )
        ;; Update project total investors
        (map-set projects project-id
          (merge project {total-investors: (+ (get total-investors project) u1)})
        )
      )
    )
    
    ;; Update project funding
    (let ((new-funding (+ (get current-funding project) investment-amount)))
      (map-set projects project-id
        (merge project {
          current-funding: new-funding,
          is-funded: (>= new-funding (get funding-goal project))
        })
      )
    )
    
    ;; Update user profile
    (map-set users tx-sender
      (merge current-user {
        total-invested: (+ (get total-invested current-user) investment-amount),
        reputation-score: (+ (get reputation-score current-user) u5)
      })
    )
    
    (ok true)
  )
)

;; Project creator can close project and withdraw funds (if funded)
(define-public (close-project (project-id uint))
  (let 
    (
      (project (try! (get-validated-project project-id)))
      (withdrawal-amount (get current-funding project))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active project) ERR-PROJECT-CLOSED)
    (asserts! (get is-funded project) ERR-PROJECT-NOT-FUNDED)
    
    ;; Transfer funds to project creator
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get creator project))))
    
    ;; Update project status
    (map-set projects project-id
      (merge project {is-active: false})
    )
    
    (ok withdrawal-amount)
  )
)

;; Distribute returns to investors (called by project creator)
(define-public (distribute-returns (project-id uint))
  (let 
    (
      (project (try! (get-validated-project project-id)))
    )
    (asserts! (is-eq tx-sender (get creator project)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-active project)) ERR-PROJECT-CLOSED)
    (asserts! (not (get returns-distributed project)) ERR-ALREADY-WITHDRAWN)
    
    ;; Mark returns as distributed
    (map-set projects project-id
      (merge project {returns-distributed: true})
    )
    
    (ok true)
  )
)

;; Individual investor claims their returns
(define-public (claim-returns (project-id uint))
  (let 
    (
      (project (try! (get-validated-project project-id)))
      (investment (unwrap! (map-get? investments {investor: tx-sender, project-id: project-id}) ERR-NOT-FOUND))
      (returns-amount (unwrap! (calculate-returns project-id (get amount investment)) ERR-INVALID-AMOUNT))
    )
    (asserts! (get returns-distributed project) ERR-PROJECT-NOT-FUNDED)
    (asserts! (not (get returns-claimed investment)) ERR-ALREADY-WITHDRAWN)
    
    ;; Transfer returns to investor
    (try! (as-contract (stx-transfer? returns-amount tx-sender tx-sender)))
    
    ;; Mark returns as claimed
    (map-set investments {investor: tx-sender, project-id: project-id}
      (merge investment {returns-claimed: true})
    )
    
    (ok returns-amount)
  )
)

;; Refund investors if project fails to reach goal by deadline
(define-public (refund-investment (project-id uint))
  (let 
    (
      (project (try! (get-validated-project project-id)))
      (investment (unwrap! (map-get? investments {investor: tx-sender, project-id: project-id}) ERR-NOT-FOUND))
      (refund-amount (get amount investment))
    )
    (asserts! (> block-height (get deadline project)) ERR-DEADLINE-NOT-REACHED)
    (asserts! (not (get is-funded project)) ERR-PROJECT-NOT-FUNDED)
    (asserts! (not (get returns-claimed investment)) ERR-ALREADY-WITHDRAWN)
    
    ;; Transfer refund to investor
    (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
    
    ;; Mark as refunded
    (map-set investments {investor: tx-sender, project-id: project-id}
      (merge investment {returns-claimed: true})
    )
    
    ;; Update project funding
    (map-set projects project-id
      (merge project {current-funding: (- (get current-funding project) refund-amount)})
    )
    
    (ok refund-amount)
  )
)

;; Admin function to withdraw platform fees (only contract owner)
(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get platform-treasury)) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer fees to contract owner
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    
    ;; Update treasury
    (var-set platform-treasury (- (var-get platform-treasury) amount))
    
    (ok amount)
  )
)

;; Emergency pause function (only contract owner) with enhanced validation
(define-public (emergency-pause-project (project-id uint))
  (let 
    (
      (project (try! (get-validated-project project-id)))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active project) ERR-PROJECT-CLOSED)
    
    (map-set projects project-id
      (merge project {is-active: false})
    )
    
    (ok true)
  )
)