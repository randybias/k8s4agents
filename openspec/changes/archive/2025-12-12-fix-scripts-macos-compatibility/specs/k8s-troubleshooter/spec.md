## MODIFIED Requirements

### Requirement: Diagnostic Scripts

The skill SHALL provide executable scripts for common diagnostic operations that can be run directly without modification. **Scripts SHALL be the recommended first choice before manual command workflows.** **Scripts SHALL be portable across macOS and Linux without requiring additional dependencies.**

#### Scenario: Cluster health check script
- **WHEN** user needs cluster overview
- **THEN** script MUST check: node status, system pod health, resource pressure, API server responsiveness
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Pod diagnostics script
- **WHEN** user needs detailed pod analysis
- **THEN** script MUST collect: pod status, events, container logs, resource usage, restart history
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Network debugging script
- **WHEN** user needs network troubleshooting
- **THEN** script MUST test: DNS resolution, service endpoints, network policy effects, pod-to-pod connectivity
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Scripts are composable
- **WHEN** scripts are designed
- **THEN** scripts MUST use functions that can be called individually or composed for specific investigations

#### Scenario: Helm release debugging script
- **WHEN** user needs Helm troubleshooting
- **THEN** script MUST cover: helm lint/template/dry-run, release status/history, pending-upgrade detection, safe cleanup guidance
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Cluster assessment script
- **WHEN** user needs comprehensive cluster assessment report
- **THEN** script `cluster_assessment.sh` MUST be invoked as the primary method
- **AND** manual assessment phases MUST be labeled as fallback only

#### Scenario: Scripts portable across macOS and Linux
- **WHEN** scripts are executed
- **THEN** scripts MUST run successfully on both macOS (BSD userland) and Linux (GNU userland)
- **AND** scripts MUST NOT require installation of additional tools (e.g., GNU coreutils via Homebrew)
- **AND** scripts MUST avoid non-portable constructs: `sed -i` without OS detection, `grep -P`, bash 4+ only features
