# Decentralized Water Quality Monitoring and Distribution System

A comprehensive blockchain-based system for monitoring water quality, treatment processes, distribution networks, and infrastructure maintenance using Clarity smart contracts.

## System Overview

This system consists of five interconnected smart contracts that provide end-to-end monitoring of municipal water systems:

### 1. Water Source Testing Contract (`water-source-testing.clar`)
- Records pH levels, contaminant concentrations, and bacterial counts
- Tracks testing timestamps and authorized personnel
- Maintains historical data for trend analysis
- Validates testing parameters against safety standards

### 2. Treatment Facility Verification Contract (`treatment-facility-verification.clar`)
- Monitors water purification processes and chemical treatment protocols
- Records treatment stages, chemical dosages, and process efficiency
- Tracks facility operator certifications and maintenance schedules
- Ensures compliance with treatment standards

### 3. Distribution Network Tracking Contract (`distribution-network-tracking.clar`)
- Maps water flow through distribution pipes and infrastructure
- Identifies and records leak locations and pressure anomalies
- Tracks flow rates, pressure levels, and network integrity
- Maintains real-time status of distribution points

### 4. Quality Alert System Contract (`quality-alert-system.clar`)
- Automatically generates alerts for water quality issues
- Issues boil water advisories and contamination warnings
- Manages alert severity levels and affected areas
- Tracks alert resolution and public notifications

### 5. Infrastructure Maintenance Contract (`infrastructure-maintenance.clar`)
- Schedules preventive maintenance for treatment and distribution systems
- Tracks repair work, replacement parts, and maintenance costs
- Manages contractor assignments and work completion verification
- Maintains equipment lifecycle and performance history

## Key Features

- **Transparency**: All water quality data is recorded on-chain for public access
- **Accountability**: Immutable records of testing, treatment, and maintenance activities
- **Real-time Monitoring**: Continuous tracking of water quality parameters
- **Automated Alerts**: Smart contract-based notification system for quality issues
- **Historical Analysis**: Long-term data storage for trend analysis and reporting
- **Compliance Tracking**: Automated verification against regulatory standards

## Data Types and Standards

### Water Quality Parameters
- pH levels (0-14 scale)
- Contaminant levels (parts per million)
- Bacterial counts (colony forming units per 100ml)
- Chemical concentrations (mg/L)

### Alert Severity Levels
- **Level 1**: Minor quality variations (informational)
- **Level 2**: Quality concerns requiring monitoring
- **Level 3**: Boil water advisory required
- **Level 4**: Do not use - immediate health risk

### Maintenance Categories
- **Preventive**: Scheduled routine maintenance
- **Corrective**: Repair of identified issues
- **Emergency**: Critical system failures
- **Upgrade**: System improvements and replacements

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation
\`\`\`bash
git clone <repository-url>
cd water-quality-system
npm install
clarinet check
\`\`\`

### Running Tests
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Contract Interactions

### Recording Water Quality Data
\`\`\`clarity
(contract-call? .water-source-testing record-test-results
u7 u50 u0 "Source-A" tx-sender)
\`\`\`

### Issuing Quality Alerts
\`\`\`clarity
(contract-call? .quality-alert-system issue-alert
u3 "High bacterial count detected" "District-1" tx-sender)
\`\`\`

### Scheduling Maintenance
\`\`\`clarity
(contract-call? .infrastructure-maintenance schedule-maintenance
"pump-station-1" "preventive" u1000000 tx-sender)
\`\`\`

## Security Considerations

- Only authorized personnel can record official test results
- Multi-signature requirements for critical system changes
- Immutable audit trail for all water quality data
- Role-based access control for different system functions

## Compliance and Regulations

This system is designed to support compliance with:
- EPA Safe Drinking Water Act standards
- Local municipal water quality regulations
- Public health reporting requirements
- Environmental monitoring mandates

## Contributing

Please read the PR-DETAILS.md file for information on contributing to this project.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
