# Tasks: Add Standardized Report Format

## 1. SKILL.md Documentation

- [ ] 1.1 Add "Standardized Report Generation" section after "Incident Response" section (~line 85)
- [ ] 1.2 Include full 6-section report template with field descriptions
- [ ] 1.3 Add severity guidelines table (P1-P4 criteria)
- [ ] 1.4 Add blast radius categories table
- [ ] 1.5 Add "Fact vs Inference Methodology" subsection
- [ ] 1.6 Add "Hypothesis Ranking" subsection with falsification test guidance
- [ ] 1.7 Add "Confidence Assessment" guidance

## 2. Template Sections

- [ ] 2.1 Section 0: Executive Triage Card template
  - Status, Severity, Impact fields
  - Primary hypothesis with confidence and "most dangerous assumption"
  - Top 3 recommended actions table
  - Escalation triggers
  - Alternative hypotheses considered

- [ ] 2.2 Section 1: Problem Statement template
  - Symptoms description
  - When started / detection method
  - Exit criteria checklist

- [ ] 2.3 Section 2: Assessment & Findings template
  - Classification table
  - Scope (confirmed/suspected/unaffected)
  - Observed Facts list (labeled, verifiable)
  - Derived Inferences list (labeled with confidence)
  - What Changed table
  - Constraints encountered

- [ ] 2.4 Section 3: Root Cause Analysis template
  - H1/H2/H3 hypothesis structure
  - Evidence for/against format
  - Falsification test field
  - Remaining unknowns

- [ ] 2.5 Section 4: Remediation Plan template
  - Immediate mitigation table (action, validation, rollback)
  - Fix forward table
  - Prevention improvements table

- [ ] 2.6 Section 5: Proof of Work template
  - Inputs consulted table
  - Commands executed code block
  - Constraints documented

- [ ] 2.7 Section 6: Supporting Evidence template
  - Log excerpts format
  - kubectl output format

## 3. Validation

- [ ] 3.1 Test with Claude agent using k8s-troubleshooter skill
- [ ] 3.2 Verify agent follows template structure
- [ ] 3.3 Verify fact/inference separation is applied
- [ ] 3.4 Verify hypothesis ranking includes falsification tests

## Dependencies

- No dependencies on other changes
- No script modifications required (documentation-only)

## Notes

- This is an additive change to SKILL.md
- Existing incident triage workflows remain unchanged
- Agents should be instructed to follow this format when generating investigation reports
