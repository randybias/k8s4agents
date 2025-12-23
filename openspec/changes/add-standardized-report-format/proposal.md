# Change: Add Standardized Report Format to k8s-troubleshooter

## Why

AI triage agents produce inconsistent report formats, making it difficult to:
- Quickly assess incident severity and recommended actions
- Audit agent reasoning and evidence
- Compare investigations across different agents or incidents
- Trust AI-generated findings when fact vs inference is unclear

A standardized report format with front-loaded executive summary, explicit fact/inference separation, hypothesis ranking with falsification tests, and proof-of-work documentation will make triage reports more actionable, auditable, and trustworthy.

## What Changes

Add a new "Standardized Report Generation" section to SKILL.md containing:

1. **6-Section Report Template**
   - Section 0: Executive Triage Card (front-loaded 30-60 second summary)
   - Section 1: Problem Statement
   - Section 2: Assessment & Findings (with fact/inference separation)
   - Section 3: Root Cause Analysis (ranked hypotheses with falsification tests)
   - Section 4: Remediation Plan (with validation and rollback steps)
   - Section 5: Proof of Work (commands executed, sources consulted)
   - Section 6: Supporting Evidence

2. **Methodology Guidance**
   - Fact vs Inference separation methodology
   - Hypothesis ranking with falsification tests
   - Confidence level assessment
   - "Most dangerous assumption" identification

3. **Reference Tables**
   - Severity guidelines (P1-P4)
   - Blast radius categories (single pod to cluster-wide)

## Impact

- Affected specs: k8s-troubleshooter
- Affected code: SKILL.md (documentation addition, no script changes required initially)
- Breaking changes: None - additive only
