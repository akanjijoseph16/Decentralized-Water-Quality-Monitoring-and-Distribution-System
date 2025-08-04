;; Infrastructure Maintenance Contract
;; Schedules and tracks repairs to water treatment and distribution systems

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-PRIORITY (err u501))
(define-constant ERR-INVALID-COST (err u502))
(define-constant ERR-TASK-NOT-FOUND (err u503))
(define-constant ERR-CONTRACTOR-NOT-FOUND (err u504))

;; Data Variables
(define-data-var next-task-id uint u1)
(define-data-var next-contractor-id uint u1)
(define-data-var maintenance-budget uint u1000000)

;; Data Maps
(define-map authorized-managers principal bool)
(define-map maintenance-tasks
  { task-id: uint }
  {
    equipment-id: (string-ascii 100),
    task-type: (string-ascii 50),
    description: (string-ascii 500),
    priority: uint,
    estimated-cost: uint,
    actual-cost: (optional uint),
    scheduled-date: uint,
    completion-date: (optional uint),
    assigned-contractor: (optional uint),
    status: (string-ascii 20),
    created-by: principal,
    created-at: uint
  }
)

(define-map certified-contractors
  { contractor-id: uint }
  {
    name: (string-ascii 100),
    specialization: (string-ascii 100),
    certification-level: uint,
    contact-info: (string-ascii 200),
    performance-rating: uint,
    active: bool,
    registered-date: uint
  }
)

(define-map equipment-registry
  { equipment-id: (string-ascii 100) }
  {
    name: (string-ascii 100),
    equipment-type: (string-ascii 50),
    manufacturer: (string-ascii 100),
    model: (string-ascii 50),
    install-date: uint,
    warranty-expiry: uint,
    last-maintenance: (optional uint),
    condition: (string-ascii 20),
    location: (string-ascii 200)
  }
)

(define-map maintenance-schedules
  { equipment-id: (string-ascii 100), schedule-type: (string-ascii 50) }
  {
    frequency-days: uint,
    last-performed: uint,
    next-due: uint,
    estimated-cost: uint,
    assigned-contractor: (optional uint)
  }
)

(define-map work-orders
  { task-id: uint }
  {
    work-description: (string-ascii 1000),
    parts-required: (string-ascii 500),
    labor-hours: uint,
    safety-requirements: (string-ascii 300),
    completion-notes: (optional (string-ascii 500)),
    quality-check: bool
  }
)

;; Authorization Functions
(define-public (authorize-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-managers manager true))
  )
)

(define-public (revoke-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-managers manager false))
  )
)

;; Equipment Management
(define-public (register-equipment
  (equipment-id (string-ascii 100))
  (name (string-ascii 100))
  (equipment-type (string-ascii 50))
  (manufacturer (string-ascii 100))
  (model (string-ascii 50))
  (warranty-expiry uint)
  (location (string-ascii 200))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set equipment-registry
      { equipment-id: equipment-id }
      {
        name: name,
        equipment-type: equipment-type,
        manufacturer: manufacturer,
        model: model,
        install-date: block-height,
        warranty-expiry: warranty-expiry,
        last-maintenance: none,
        condition: "NEW",
        location: location
      }
    ))
  )
)

(define-public (update-equipment-condition (equipment-id (string-ascii 100)) (condition (string-ascii 20)))
  (let
    (
      (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (match (map-get? equipment-registry { equipment-id: equipment-id })
      equipment-data (ok (map-set equipment-registry
        { equipment-id: equipment-id }
        (merge equipment-data { condition: condition })
      ))
      ERR-TASK-NOT-FOUND
    )
  )
)

;; Contractor Management
(define-public (register-contractor
  (name (string-ascii 100))
  (specialization (string-ascii 100))
  (certification-level uint)
  (contact-info (string-ascii 200))
)
  (let
    (
      (contractor-id (var-get next-contractor-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= certification-level u5) (err u505))

    (map-set certified-contractors
      { contractor-id: contractor-id }
      {
        name: name,
        specialization: specialization,
        certification-level: certification-level,
        contact-info: contact-info,
        performance-rating: u5,
        active: true,
        registered-date: block-height
      }
    )

    (var-set next-contractor-id (+ contractor-id u1))
    (ok contractor-id)
  )
)

(define-public (update-contractor-rating (contractor-id uint) (rating uint))
  (let
    (
      (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! (<= rating u10) (err u506))
    (match (map-get? certified-contractors { contractor-id: contractor-id })
      contractor-data (ok (map-set certified-contractors
        { contractor-id: contractor-id }
        (merge contractor-data { performance-rating: rating })
      ))
      ERR-CONTRACTOR-NOT-FOUND
    )
  )
)

;; Maintenance Task Management
(define-public (schedule-maintenance
  (equipment-id (string-ascii 100))
  (task-type (string-ascii 50))
  (description (string-ascii 500))
  (priority uint)
  (estimated-cost uint)
  (scheduled-date uint)
)
  (let
    (
      (task-id (var-get next-task-id))
      (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! (<= priority u5) ERR-INVALID-PRIORITY)
    (asserts! (<= estimated-cost (var-get maintenance-budget)) ERR-INVALID-COST)
    (asserts! (is-some (map-get? equipment-registry { equipment-id: equipment-id })) ERR-TASK-NOT-FOUND)

    (map-set maintenance-tasks
      { task-id: task-id }
      {
        equipment-id: equipment-id,
        task-type: task-type,
        description: description,
        priority: priority,
        estimated-cost: estimated-cost,
        actual-cost: none,
        scheduled-date: scheduled-date,
        completion-date: none,
        assigned-contractor: none,
        status: "SCHEDULED",
        created-by: tx-sender,
        created-at: block-height
      }
    )

    (var-set next-task-id (+ task-id u1))
    (ok task-id)
  )
)

(define-public (assign-contractor (task-id uint) (contractor-id uint))
  (let
    (
      (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
      (contractor-exists (is-some (map-get? certified-contractors { contractor-id: contractor-id })))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! contractor-exists ERR-CONTRACTOR-NOT-FOUND)
    (match (map-get? maintenance-tasks { task-id: task-id })
      task-data (ok (map-set maintenance-tasks
        { task-id: task-id }
        (merge task-data {
          assigned-contractor: (some contractor-id),
          status: "ASSIGNED"
        })
      ))
      ERR-TASK-NOT-FOUND
    )
  )
)

(define-public (complete-maintenance (task-id uint) (actual-cost uint) (completion-notes (string-ascii 500)))
  (let
    (
      (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (match (map-get? maintenance-tasks { task-id: task-id })
      task-data
      (begin
        (map-set maintenance-tasks
          { task-id: task-id }
          (merge task-data {
            actual-cost: (some actual-cost),
            completion-date: (some block-height),
            status: "COMPLETED"
          })
        )
        (match (map-get? equipment-registry { equipment-id: (get equipment-id task-data) })
          equipment-data (map-set equipment-registry
            { equipment-id: (get equipment-id task-data) }
            (merge equipment-data { last-maintenance: (some block-height) })
          )
          true
        )
        (ok task-id)
      )
      ERR-TASK-NOT-FOUND
    )
  )
)

;; Work Order Management
(define-public (create-work-order
  (task-id uint)
  (work-description (string-ascii 1000))
  (parts-required (string-ascii 500))
  (labor-hours uint)
  (safety-requirements (string-ascii 300))
)
  (let
    (
      (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
      (task-exists (is-some (map-get? maintenance-tasks { task-id: task-id })))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! task-exists ERR-TASK-NOT-FOUND)

    (ok (map-set work-orders
      { task-id: task-id }
      {
        work-description: work-description,
        parts-required: parts-required,
        labor-hours: labor-hours,
        safety-requirements: safety-requirements,
        completion-notes: none,
        quality-check: false
      }
    ))
  )
)

;; Maintenance Scheduling
(define-public (set-maintenance-schedule
  (equipment-id (string-ascii 100))
  (schedule-type (string-ascii 50))
  (frequency-days uint)
  (estimated-cost uint)
)
  (let
    (
      (is-authorized (default-to false (map-get? authorized-managers tx-sender)))
      (equipment-exists (is-some (map-get? equipment-registry { equipment-id: equipment-id })))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! equipment-exists ERR-TASK-NOT-FOUND)

    (ok (map-set maintenance-schedules
      { equipment-id: equipment-id, schedule-type: schedule-type }
      {
        frequency-days: frequency-days,
        last-performed: block-height,
        next-due: (+ block-height frequency-days),
        estimated-cost: estimated-cost,
        assigned-contractor: none
      }
    ))
  )
)

;; Budget Management
(define-public (set-maintenance-budget (new-budget uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set maintenance-budget new-budget))
  )
)

;; Read-only Functions
(define-read-only (get-maintenance-task (task-id uint))
  (map-get? maintenance-tasks { task-id: task-id })
)

(define-read-only (get-contractor (contractor-id uint))
  (map-get? certified-contractors { contractor-id: contractor-id })
)

(define-read-only (get-equipment (equipment-id (string-ascii 100)))
  (map-get? equipment-registry { equipment-id: equipment-id })
)

(define-read-only (get-work-order (task-id uint))
  (map-get? work-orders { task-id: task-id })
)

(define-read-only (get-maintenance-schedule (equipment-id (string-ascii 100)) (schedule-type (string-ascii 50)))
  (map-get? maintenance-schedules { equipment-id: equipment-id, schedule-type: schedule-type })
)

(define-read-only (is-manager-authorized (manager principal))
  (default-to false (map-get? authorized-managers manager))
)

(define-read-only (get-next-task-id)
  (var-get next-task-id)
)

(define-read-only (get-next-contractor-id)
  (var-get next-contractor-id)
)

(define-read-only (get-maintenance-budget)
  (var-get maintenance-budget)
)

;; Analysis Functions
(define-read-only (calculate-equipment-age (equipment-id (string-ascii 100)))
  (match (map-get? equipment-registry { equipment-id: equipment-id })
    equipment-data (- block-height (get install-date equipment-data))
    u0
  )
)

(define-read-only (is-maintenance-overdue (equipment-id (string-ascii 100)) (schedule-type (string-ascii 50)))
  (match (map-get? maintenance-schedules { equipment-id: equipment-id, schedule-type: schedule-type })
    schedule-data (>= block-height (get next-due schedule-data))
    false
  )
)

(define-read-only (get-contractor-workload (contractor-id uint))
  ;; This would typically count active tasks assigned to contractor
  ;; Simplified implementation returns performance rating
  (match (map-get? certified-contractors { contractor-id: contractor-id })
    contractor-data (get performance-rating contractor-data)
    u0
  )
)

(define-read-only (calculate-maintenance-cost-efficiency (task-id uint))
  (match (map-get? maintenance-tasks { task-id: task-id })
    task-data
    (match (get actual-cost task-data)
      actual-cost-value
      (let
        (
          (estimated (get estimated-cost task-data))
          (actual actual-cost-value)
        )
        (if (<= actual estimated)
          u100
          (/ (* estimated u100) actual)
        )
      )
      u0
    )
    u0
  )
)

;; Initialize contract
(begin
  (map-set authorized-managers CONTRACT-OWNER true)
)
