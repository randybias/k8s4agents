# Change: Update Helm Release Debug Script

## Why
- Current `helm_release_debug.sh` misses critical failure modes (pre/post-install hooks, aged-out events, empty manifests) leading to minimal output and weak diagnosis.
- Helm spec requires lint/template/dry-run coverage; the script does not offer chart validation or hook/test awareness.
- Users need structured, hook-aware evidence (jobs/pods describe/logs) and optional chart/test checks surfaced in automation-first documentation.

## What Changes
- Add hook-aware diagnostics: `helm get hooks`, hook job/pod listings, describes, and log tails to explain pre-install failures and empty manifests.
- Add optional chart validation path: lint, template + kubectl client dry-run, and upgrade/install dry-run for a provided chart/values.
- Add optional post-install tests: gated `helm test --logs` with summary of failing test jobs/pods.
- Improve release state signals: clearer status/last_error reporting, aged-out events notice, and handling when no resources were rendered.
- Update documentation and slash command guide to reflect new script capabilities and flags while keeping automation-first guidance.

## Impact
- Affected spec: `k8s-troubleshooter`
- Affected code/docs (implementation phase): `skills/k8s-troubleshooter/scripts/helm_release_debug.sh`, `SKILL.md`, `commands/k8s-helm-debug.md`, and related reference notes.
