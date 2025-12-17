# Tasks: Update Helm Release Debug Script

## 1. Proposal Validation
- [x] 1.1 Review current script/doc state and align with spec gaps (hooks, dry-run, tests)
- [x] 1.2 Validate proposal with `openspec validate update-helm-release-debug-script --strict`

## 2. Script Enhancements
- [x] 2.1 Add flagged options (`--chart/--values/--set*`, `--run-tests`, `--run-dry-run`, `--diff`, `--output`) with help text
- [x] 2.2 Add hook-aware diagnostics: `helm get hooks`, hook job/pod listing, describes, and log tails
- [x] 2.3 Add release state summarization: last_error, empty-manifest notice, aged-out events messaging
- [x] 2.4 Add optional chart validation path: lint, template + client dry-run, upgrade/install dry-run
- [x] 2.5 Add optional post-install tests: gated `helm test --logs` with failure summary
- [x] 2.6 Keep macOS/Linux portability; guard optional plugin steps (helm-diff) if not installed

## 3. Documentation Updates
- [x] 3.1 Update `SKILL.md` automation-first/Helm sections with new flags and hook-aware coverage
- [x] 3.2 Refresh Helm reference notes to mention hooks/tests/dry-run flow

## 4. Validation
- [x] 4.1 Run `shellcheck` (if available) on updated script (shellcheck not installed, bash syntax check passed)
- [x] 4.2 Smoke-test `--help` and flag parsing locally; record limitations if cluster access unavailable
- [x] 4.3 Ensure no hardcoded paths remain; confirm docs use relative script paths
