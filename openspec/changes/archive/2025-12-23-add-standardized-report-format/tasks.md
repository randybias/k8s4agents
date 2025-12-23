# Tasks: Add Standardized Report Format

## 1. SKILL.md Documentation

- [x] 1.1 Add "Standardized Report Generation" section after "Incident Response" section (~line 85)
- [x] 1.2 Include full 6-section report template with field descriptions
- [x] 1.3 Add severity guidelines table (P1-P4 criteria)
- [x] 1.4 Add blast radius categories table
- [x] 1.5 Add "Fact vs Inference Methodology" subsection
- [x] 1.6 Add "Hypothesis Ranking" subsection with falsification test guidance
- [x] 1.7 Add "Confidence Assessment" guidance

## 2. Template Sections

- [x] 2.1 Section 0: Executive Triage Card template
  - Status, Severity, Impact fields
  - Primary hypothesis with confidence and "most dangerous assumption"
  - Top 3 recommended actions table
  - Escalation triggers
  - Alternative hypotheses considered

- [x] 2.2 Section 1: Problem Statement template
  - Symptoms description
  - When started / detection method
  - Exit criteria checklist

- [x] 2.3 Section 2: Assessment & Findings template
  - Classification table
  - Scope (confirmed/suspected/unaffected)
  - Observed Facts list (labeled, verifiable)
  - Derived Inferences list (labeled with confidence)
  - What Changed table
  - Constraints encountered

- [x] 2.4 Section 3: Root Cause Analysis template
  - H1/H2/H3 hypothesis structure
  - Evidence for/against format
  - Falsification test field
  - Remaining unknowns

- [x] 2.5 Section 4: Remediation Plan template
  - Immediate mitigation table (action, validation, rollback)
  - Fix forward table
  - Prevention improvements table

- [x] 2.6 Section 5: Proof of Work template
  - Inputs consulted table
  - Commands executed code block
  - Constraints documented

- [x] 2.7 Section 6: Supporting Evidence template
  - Log excerpts format
  - kubectl output format

## 3. Validation

- [x] 3.1 Test with Claude agent using k8s-troubleshooter skill
- [x] 3.2 Verify agent follows template structure
- [x] 3.3 Verify fact/inference separation is applied
- [x] 3.4 Verify hypothesis ranking includes falsification tests

## Validation Results

**Test Environment**:
- k0s cluster (rdev-eastus, v1.34.2+k0s, ARM64)
- kind cluster (events-test, v1.35.0)

**Test Scenarios Created**:
- CrashLoopBackOff pods (exit code 1, application errors)
- OOMKilled pods (memory limits exceeded)
- Pending pods (impossible resource requests)
- CreateContainerConfigError (missing ConfigMap)
- Init container stuck (sleep infinity)
- Readiness probe failures (404 on health endpoint)
- Orphan service (no backing pods)

**Validation Findings**:

1. **Template Structure**: Agent successfully generated all 7 sections (Executive Triage Card through Supporting Evidence)

2. **Fact/Inference Separation**: Agent correctly labeled facts with `[FACT-n]` and inferences with `[INF-n]`, including confidence levels and falsification conditions

3. **Hypothesis Ranking**: Agent presented H1/H2/H3 hypotheses with:
   - Confidence levels (High/Medium/Low)
   - Evidence for and against
   - Explicit falsification tests with commands

4. **Report Depth Guidelines**: After adding P3/P4 guidance, agent correctly produced concise reports:
   - Full Executive Triage Card
   - Abbreviated other sections
   - Low-confidence hypotheses as 1-line bullets
   - "What Changed" omitted when unknown
   - ~60% reduction in report length for P3

**Outcome**: All validation criteria met. Report format is actionable, auditable, and scales appropriately with incident severity.

## Dependencies

- No dependencies on other changes
- No script modifications required (documentation-only)

## Notes

- This is an additive change to SKILL.md
- Existing incident triage workflows remain unchanged
- Agents should be instructed to follow this format when generating investigation reports
- Report Depth Guidelines added to scale verbosity with severity (P1/P2 full, P3 concise, P4 minimal)
