# Tasks: Add Automation-First Guidance

## 1. Update SKILL.md Documentation

- [x] 1.1 Add "Automation First" section immediately after "Quick Start: Slash Commands" section
  - Include priority guidance (scripts first, manual as fallback)
  - Add table mapping tasks to scripts with full invocation examples
  - Include script location path and parameter examples

- [x] 1.2 Update Workflow 6 (Cluster Health / `/full-diag`) to lead with automation
  - Add "AUTOMATED SCRIPT AVAILABLE" callout box at workflow start
  - Move `cluster_health_check.sh` invocation before manual commands
  - Label manual steps as "Manual Fallback (for understanding or when script unavailable)"

- [x] 1.3 Update Workflow 7 (Cluster Assessment / `/cluster-assessment`) to lead with automation
  - Add "AUTOMATED SCRIPT AVAILABLE" callout box at workflow start
  - Move `cluster_assessment.sh` invocation before manual phases
  - Label manual phases as "Manual Fallback" section

- [x] 1.4 Update "Scripts Reference" section at bottom of SKILL.md
  - Add explicit "Use these scripts first" guidance
  - Include full invocation examples for each script
  - Add note about checking script help with `-h` flag

## 2. Update README.md

- [x] 2.1 Add "Usage Priority" section near top of README
  - State automation-first principle clearly
  - Reference SKILL.md for detailed workflows

- [x] 2.2 Update "Diagnostic Scripts" section to emphasize they should be first choice
  - Move higher in document structure
  - Add explicit "prefer these over manual commands" note

## 3. Verification

- [x] 3.1 Test skill invocation to verify new guidance is prominent
  - Invoke skill and verify "Automation First" section appears early
  - Confirm script commands are visible before manual workflows

- [x] 3.2 Validate spec alignment
  - Verify changes satisfy new Automation-First Behavior requirement
  - Run `openspec validate k8s-troubleshooter --strict`
