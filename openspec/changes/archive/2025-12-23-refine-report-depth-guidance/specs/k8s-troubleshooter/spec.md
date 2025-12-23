# k8s-troubleshooter Spec Delta

## ADDED Requirements

### Requirement: Severity-Based Report Depth

The skill SHALL provide guidance for calibrating report depth based on incident severity.

#### Scenario: P1/P2 incident reporting
- **WHEN** investigating a P1 or P2 severity incident
- **THEN** all 6 report sections are fully populated
- **AND** multiple ranked hypotheses are provided with falsification tests
- **AND** complete evidence chains with timestamps are included
- **AND** full remediation plans with rollback procedures are documented

#### Scenario: P3 incident reporting
- **WHEN** investigating a P3 severity incident
- **THEN** the Executive Card is fully populated
- **AND** other sections use concise format
- **AND** only the primary hypothesis is documented
- **AND** evidence is abbreviated to key findings only
- **AND** remediation focuses on the direct fix without alternatives

#### Scenario: P4 incident reporting
- **WHEN** investigating a P4 severity incident
- **THEN** the Executive Card uses abbreviated format
- **AND** remaining content is a single summary paragraph
- **AND** Supporting Evidence section may be omitted entirely

## Cross-References

- **Depends on**: add-standardized-report-format (archived) - provides 6-section structure
- **Related**: nightcrier/generalize-triage-system-prompt - system prompt delegates to skill
