## ADDED Requirements

### Requirement: Automation-First Behavior

The skill SHALL prioritize automation scripts over manual command sequences when scripts are available for the requested task.

#### Scenario: Script recommended before manual workflow
- **WHEN** a workflow has an associated automation script in `scripts/` directory
- **THEN** the skill documentation MUST present the script invocation command before any manual kubectl commands
- **AND** the script command MUST include full path and common parameters

#### Scenario: Automation-first section visible at top
- **WHEN** the skill is invoked
- **THEN** an "Automation First" section MUST appear within the first 100 lines of SKILL.md
- **AND** the section MUST include a table mapping tasks to their automation scripts

#### Scenario: Manual workflows labeled as fallback
- **WHEN** a workflow has both script and manual options
- **THEN** the manual workflow section MUST be explicitly labeled as "Fallback" or "For Understanding"
- **AND** the script option MUST be labeled as the primary/recommended approach

#### Scenario: Script invocation includes working examples
- **WHEN** documenting a script
- **THEN** the documentation MUST include at least one complete, copy-paste ready invocation example
- **AND** the example MUST use the full path relative to skill directory

---

## MODIFIED Requirements

### Requirement: Diagnostic Scripts

The skill SHALL provide executable scripts for common diagnostic operations that can be run directly without modification. **Scripts SHALL be the recommended first choice before manual command workflows.**

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
