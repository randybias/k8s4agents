## ADDED Requirements

### Requirement: Helm release failure evidence capture

The Helm troubleshooting script SHALL surface hook-aware failure evidence, explain absent resources, and optionally validate charts/tests when requested.

#### Scenario: Hook failure evidence
- **WHEN** a release fails during hooks or reports a failed/pending state
- **THEN** the script MUST fetch `helm get hooks`, list hook Jobs/Pods, and collect describes plus log tails for failed hook Pods to expose backoff/exit reasons

#### Scenario: Empty manifest clarity
- **WHEN** `helm get manifest` produces no resources
- **THEN** the script MUST print an explicit notice that no resources were rendered/applied
- **AND** MUST hint that hook failures or template errors can prevent resource creation
- **AND** MUST note when events are absent or aged out so users know why event output is empty

#### Scenario: Optional chart validation
- **WHEN** the user provides a chart path (and optional values)
- **THEN** the script MUST run lint, template with debug piped to client-side dry-run, and an upgrade/install dry-run with debug
- **AND** MUST degrade gracefully (skip with a message) when no chart path is provided

#### Scenario: Optional chart tests
- **WHEN** the user opts to run chart tests
- **THEN** the script MUST run `helm test --logs` and summarize failing tests with relevant Job/Pod logs

#### Scenario: Release status summary
- **WHEN** reporting release state
- **THEN** the script MUST surface Helm status, last_error (if present), and clearly indicate pending/failed states before running deeper diagnostics
