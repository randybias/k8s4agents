# Refine Report Depth Guidance

## Problem Statement

The standardized 6-section triage report format produces verbose output regardless of incident severity. For lower-priority incidents (P3/P4), this verbosity is unnecessary and wastes tokens without adding value.

Example: A P3 CrashLoopBackOff incident with an obvious root cause (missing ConfigMap) generated a full-detail report with multiple hypotheses, extensive evidence sections, and exhaustive supporting data - when a concise summary would suffice.

## Proposed Solution

Add severity-based depth guidance to the report format section of SKILL.md. This tells agents to calibrate their report detail level based on incident priority:

| Severity | Executive Card | Other Sections |
|----------|---------------|----------------|
| P1/P2 (Critical/High) | Full detail | Full detail - all hypotheses, complete evidence chains |
| P3 (Medium) | Full detail | Concise - primary hypothesis only, abbreviated evidence |
| P4 (Low) | Abbreviated | Minimal - summary paragraph only |

### Specific Guidance

**P1/P2 Reports:**
- All 6 sections fully populated
- Multiple ranked hypotheses with falsification tests
- Complete evidence chains with timestamps
- Full remediation plans with rollback procedures

**P3 Reports:**
- Executive Card: Full detail (this is always the priority)
- Problem Statement: Concise (2-3 sentences)
- Assessment: Primary findings only, skip secondary observations
- Root Cause: Single most likely hypothesis, brief evidence
- Remediation: Direct fix, skip alternatives
- Proof of Work: Key commands only, skip verbose output

**P4 Reports:**
- Executive Card: Abbreviated (skip "Most Dangerous Assumption")
- Other sections: Single paragraph summary combining findings, cause, and fix
- Supporting Evidence: Omit entirely unless specifically requested

## Success Criteria

1. P3/P4 reports are 40-60% shorter than P1/P2 reports
2. Critical information (root cause, fix) preserved regardless of severity
3. Token usage reduced for routine incidents

## Scope

**In Scope:**
- Adding depth guidance table to SKILL.md report format section
- Adding per-severity section guidance

**Out of Scope:**
- Changes to the 6-section structure itself
- Changes to fact/inference labeling conventions
- System prompt modifications (handled in nightcrier)

## Dependencies

- Requires `add-standardized-report-format` to be applied first (already archived)
