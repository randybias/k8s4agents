# Tasks: Refine Report Depth Guidance

## Phase 1: Update SKILL.md

- [x] 1.1 Add depth guidance table after the report format section
  - Insert severity-based depth table (P1/P2, P3, P4)
  - Add brief explanation of calibration intent

- [x] 1.2 Add per-severity section guidance
  - P1/P2: Full detail instructions
  - P3: Concise mode instructions (primary hypothesis only)
  - P4: Minimal mode instructions (summary paragraph)

- [x] 1.3 Add example snippets showing depth difference
  - Brief P3 example showing abbreviated sections
  - Contrast with full P1/P2 format
  - Note: Validated through live testing - P3 reports generated ~60% shorter

## Validation Criteria

Each task is considered complete when:
- [x] SKILL.md updated with depth guidance
- [x] Guidance is clear and actionable for AI agents
- [x] No conflicts with existing report format structure

## Validation Results

- Tested with P3 incident on k0s cluster (report-format-test namespace)
- Agent correctly produced concise report following P3 guidelines
- ~60% reduction in report length compared to full P1/P2 format
- Executive Triage Card preserved full detail as specified

## Dependencies

- Requires `add-standardized-report-format` already applied (archived 2025-12-23)
