## Context
- `helm_release_debug.sh` currently only captures status/history/values/manifests/events/pods and misses hook failures, empty renders, and optional chart/test validation.
- Hook failures often produce no resources or events; we need explicit hook/job/pod evidence collection and clearer status messaging.
- Users may optionally supply chart paths/values to lint/template/dry-run locally; plugin usage (helm-diff) and helm test should be opt-in and non-fatal.

## Goals / Non-Goals
- Goals: hook-aware evidence, empty-manifest clarity, optional chart validation and helm test flow, portable scripting, concise summaries.
- Non-Goals: rewrite other scripts, change remediation guidance, or require new dependencies/plugins.

## Decisions
- Provide opt-in flags for chart validation (`--chart`), dry-run, tests, and diff; skip gracefully when not requested or tooling absent.
- Keep core flow resilient: continue collecting data even when some commands fail; highlight last_error/pending/failed status early.
- Limit output volume with log tails and sectioned summaries; prefer text-first over structured JSON for now.

## Risks / Trade-offs
- Collecting many describes/logs can get noisy; mitigate with tailing and clear section headers.
- Optional plugin usage could fragment experience; address with detection + clear skip messages instead of failing.

## Open Questions
- Should we support structured JSON output in this iteration or defer to a follow-up? (Proposed: defer unless requested.)
