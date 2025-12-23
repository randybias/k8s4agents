## ADDED Requirements

### Requirement: Standardized Report Generation

The skill SHALL provide a standardized report template and methodology for generating consistent, auditable, actionable triage reports.

#### Scenario: Six-section report structure

- **WHEN** agent generates an investigation report
- **THEN** report MUST follow the six-section structure:
  - Section 0: Executive Triage Card
  - Section 1: Problem Statement
  - Section 2: Assessment & Findings
  - Section 3: Root Cause Analysis
  - Section 4: Remediation Plan
  - Section 5: Proof of Work
  - Section 6: Supporting Evidence

#### Scenario: Executive Triage Card front-loaded

- **WHEN** report is generated
- **THEN** Section 0 (Executive Triage Card) MUST be complete and actionable within 30-60 seconds of reading
- **AND** MUST include: Status, Severity, Impact, Primary Hypothesis with confidence, Top 3 Actions, Escalation Triggers
- **AND** MUST include "Most Dangerous Assumption" field

#### Scenario: Fact vs inference separation

- **WHEN** agent documents findings in Section 2
- **THEN** findings MUST be explicitly separated into:
  - "Observed Facts" (direct observations, verifiable)
  - "Derived Inferences" (interpretations, labeled with confidence)
- **AND** each inference MUST reference which facts it is based on

#### Scenario: Hypothesis ranking with falsification tests

- **WHEN** agent performs root cause analysis in Section 3
- **THEN** hypotheses MUST be ranked (H1 most likely, H2, H3)
- **AND** each hypothesis MUST include:
  - Evidence supporting it
  - Evidence against it or gaps
  - A falsification test (what would disprove it quickly)
  - Confidence level (High/Medium/Low)

#### Scenario: Alternative hypotheses documented

- **WHEN** agent completes Executive Triage Card
- **THEN** card MUST include 1-3 alternative hypotheses considered
- **AND** each alternative MUST explain why it is less likely than primary

#### Scenario: Proof of work documentation

- **WHEN** agent generates Section 5
- **THEN** report MUST document:
  - All inputs consulted (with timestamps)
  - All commands executed (exact commands)
  - Constraints encountered (permissions, missing data)

#### Scenario: Remediation plan with validation

- **WHEN** agent provides remediation steps in Section 4
- **THEN** each step MUST include:
  - The specific action
  - How to validate success
  - How to rollback if needed

#### Scenario: Severity classification guidance

- **WHEN** agent assigns severity
- **THEN** skill MUST provide severity guidelines:
  - P1: Production down, all users affected, revenue impact
  - P2: Major feature degraded, significant user impact
  - P3: Minor feature affected, workaround available
  - P4: Low impact, cosmetic, monitoring-only

#### Scenario: Blast radius classification

- **WHEN** agent assesses blast radius
- **THEN** skill MUST use categories:
  - Single Pod: One pod affected, service functional
  - Namespace: Multiple pods in namespace
  - Multi-Namespace: Multiple namespaces impacted
  - Cluster-Wide: Control plane or cluster-level resources
