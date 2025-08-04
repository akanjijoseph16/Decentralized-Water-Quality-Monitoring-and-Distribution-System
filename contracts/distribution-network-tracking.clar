;; Distribution Network Tracking Contract
;; Maps water flow through pipes and identifies leak locations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-PRESSURE (err u301))
(define-constant ERR-INVALID-FLOW-RATE (err u302))
(define-constant ERR-NODE-NOT-FOUND (err u303))
(define-constant ERR-PIPE-NOT-FOUND (err u304))

;; Data Variables
(define-data-var next-node-id uint u1)
(define-data-var next-pipe-id uint u1)
(define-data-var next-reading-id uint u1)

;; Data Maps
(define-map authorized-technicians principal bool)
(define-map network-nodes
  { node-id: uint }
  {
    name: (string-ascii 100),
    node-type: (string-ascii 50),
    latitude: int,
    longitude: int,
    elevation: uint,
    active: bool,
    installed-date: uint
  }
)

(define-map distribution-pipes
  { pipe-id: uint }
  {
    from-node: uint,
    to-node: uint,
    diameter-mm: uint,
    material: (string-ascii 50),
    length-meters: uint,
    install-date: uint,
    condition: (string-ascii 20),
    active: bool
  }
)

(define-map pressure-readings
  { reading-id: uint }
  {
    node-id: uint,
    pressure-psi: uint,
    flow-rate-gpm: uint,
    temperature: uint,
    technician: principal,
    timestamp: uint,
    anomaly-detected: bool
  }
)

(define-map leak-reports
  { pipe-id: uint, report-date: uint }
  {
    severity: uint,
    estimated-loss-gallons: uint,
    repair-priority: uint,
    reported-by: principal,
    status: (string-ascii 20),
    repair-date: (optional uint)
  }
)

(define-map node-connections
  { node-id: uint }
  { connected-pipes: (list 10 uint) }
)

;; Authorization Functions
(define-public (authorize-technician (technician principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-technicians technician true))
  )
)

(define-public (revoke-technician (technician principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-technicians technician false))
  )
)

;; Network Infrastructure Management
(define-public (add-network-node
  (name (string-ascii 100))
  (node-type (string-ascii 50))
  (latitude int)
  (longitude int)
  (elevation uint)
)
  (let
    (
      (node-id (var-get next-node-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set network-nodes
      { node-id: node-id }
      {
        name: name,
        node-type: node-type,
        latitude: latitude,
        longitude: longitude,
        elevation: elevation,
        active: true,
        installed-date: block-height
      }
    )
    (map-set node-connections { node-id: node-id } { connected-pipes: (list) })
    (var-set next-node-id (+ node-id u1))
    (ok node-id)
  )
)

(define-public (add-distribution-pipe
  (from-node uint)
  (to-node uint)
  (diameter-mm uint)
  (material (string-ascii 50))
  (length-meters uint)
)
  (let
    (
      (pipe-id (var-get next-pipe-id))
      (from-exists (is-some (map-get? network-nodes { node-id: from-node })))
      (to-exists (is-some (map-get? network-nodes { node-id: to-node })))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! from-exists ERR-NODE-NOT-FOUND)
    (asserts! to-exists ERR-NODE-NOT-FOUND)

    (map-set distribution-pipes
      { pipe-id: pipe-id }
      {
        from-node: from-node,
        to-node: to-node,
        diameter-mm: diameter-mm,
        material: material,
        length-meters: length-meters,
        install-date: block-height,
        condition: "GOOD",
        active: true
      }
    )

    (var-set next-pipe-id (+ pipe-id u1))
    (ok pipe-id)
  )
)

;; Monitoring Functions
(define-public (record-pressure-reading
  (node-id uint)
  (pressure-psi uint)
  (flow-rate-gpm uint)
  (temperature uint)
)
  (let
    (
      (reading-id (var-get next-reading-id))
      (is-authorized (default-to false (map-get? authorized-technicians tx-sender)))
      (node-exists (is-some (map-get? network-nodes { node-id: node-id })))
      (anomaly (or (> pressure-psi u150) (< pressure-psi u20)))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! node-exists ERR-NODE-NOT-FOUND)
    (asserts! (<= pressure-psi u200) ERR-INVALID-PRESSURE)
    (asserts! (<= flow-rate-gpm u10000) ERR-INVALID-FLOW-RATE)

    (map-set pressure-readings
      { reading-id: reading-id }
      {
        node-id: node-id,
        pressure-psi: pressure-psi,
        flow-rate-gpm: flow-rate-gpm,
        temperature: temperature,
        technician: tx-sender,
        timestamp: block-height,
        anomaly-detected: anomaly
      }
    )

    (var-set next-reading-id (+ reading-id u1))
    (ok reading-id)
  )
)

;; Leak Management
(define-public (report-leak
  (pipe-id uint)
  (severity uint)
  (estimated-loss-gallons uint)
  (repair-priority uint)
)
  (let
    (
      (is-authorized (default-to false (map-get? authorized-technicians tx-sender)))
      (pipe-exists (is-some (map-get? distribution-pipes { pipe-id: pipe-id })))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! pipe-exists ERR-PIPE-NOT-FOUND)
    (asserts! (<= severity u5) (err u305))
    (asserts! (<= repair-priority u5) (err u306))

    (ok (map-set leak-reports
      { pipe-id: pipe-id, report-date: block-height }
      {
        severity: severity,
        estimated-loss-gallons: estimated-loss-gallons,
        repair-priority: repair-priority,
        reported-by: tx-sender,
        status: "REPORTED",
        repair-date: none
      }
    ))
  )
)

(define-public (update-leak-status (pipe-id uint) (report-date uint) (new-status (string-ascii 20)))
  (let
    (
      (is-authorized (default-to false (map-get? authorized-technicians tx-sender)))
    )
    (asserts! (or is-authorized (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (match (map-get? leak-reports { pipe-id: pipe-id, report-date: report-date })
      leak-data (ok (map-set leak-reports
        { pipe-id: pipe-id, report-date: report-date }
        (merge leak-data {
          status: new-status,
          repair-date: (if (is-eq new-status "REPAIRED") (some block-height) (get repair-date leak-data))
        })
      ))
      ERR-PIPE-NOT-FOUND
    )
  )
)

;; Infrastructure Status Updates
(define-public (update-pipe-condition (pipe-id uint) (condition (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (match (map-get? distribution-pipes { pipe-id: pipe-id })
      pipe-data (ok (map-set distribution-pipes
        { pipe-id: pipe-id }
        (merge pipe-data { condition: condition })
      ))
      ERR-PIPE-NOT-FOUND
    )
  )
)

(define-public (deactivate-node (node-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (match (map-get? network-nodes { node-id: node-id })
      node-data (ok (map-set network-nodes
        { node-id: node-id }
        (merge node-data { active: false })
      ))
      ERR-NODE-NOT-FOUND
    )
  )
)

;; Read-only Functions
(define-read-only (get-network-node (node-id uint))
  (map-get? network-nodes { node-id: node-id })
)

(define-read-only (get-distribution-pipe (pipe-id uint))
  (map-get? distribution-pipes { pipe-id: pipe-id })
)

(define-read-only (get-pressure-reading (reading-id uint))
  (map-get? pressure-readings { reading-id: reading-id })
)

(define-read-only (get-leak-report (pipe-id uint) (report-date uint))
  (map-get? leak-reports { pipe-id: pipe-id, report-date: report-date })
)

(define-read-only (is-technician-authorized (technician principal))
  (default-to false (map-get? authorized-technicians technician))
)

(define-read-only (get-next-node-id)
  (var-get next-node-id)
)

(define-read-only (get-next-pipe-id)
  (var-get next-pipe-id)
)

(define-read-only (get-next-reading-id)
  (var-get next-reading-id)
)

;; Network Analysis Functions
(define-read-only (calculate-network-efficiency (node-id uint))
  (match (map-get? network-nodes { node-id: node-id })
    node-data
    (if (get active node-data)
      u100
      u0
    )
    u0
  )
)

(define-read-only (get-pipe-health-score (pipe-id uint))
  (match (map-get? distribution-pipes { pipe-id: pipe-id })
    pipe-data
    (let
      (
        (condition (get condition pipe-data))
        (age (- block-height (get install-date pipe-data)))
      )
      (if (is-eq condition "EXCELLENT")
        u100
        (if (is-eq condition "GOOD")
          u80
          (if (is-eq condition "FAIR")
            u60
            (if (is-eq condition "POOR")
              u40
              u20
            )
          )
        )
      )
    )
    u0
  )
)

;; Initialize contract
(begin
  (map-set authorized-technicians CONTRACT-OWNER true)
)
