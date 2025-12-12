# Change: Fix Scripts macOS Compatibility

## Why

The k8s-troubleshooter scripts fail on macOS due to GNU/BSD sed incompatibility:
- `sed -i.bak "s|pattern|replacement|g"` fails when replacement contains newlines or special characters
- macOS uses BSD sed which has different multiline handling than GNU sed
- The `cluster_assessment.sh` script fails immediately with: `sed: 1: "s|{{NODE_SUMMARY}}|| ev ...": bad flag in substitute command: 'e'`

Scripts must work on both macOS (developer laptops) and Linux (CI/CD, servers) without requiring users to install GNU tools.

## What Changes

- **Rewrite sed-based template substitution** in `cluster_assessment.sh` to use portable approaches:
  - Use `awk` for multiline replacements (POSIX-compliant)
  - Or generate report content inline without template files
  - Or use shell variable expansion with heredocs
- **Audit all scripts** for other BSD/GNU incompatibilities:
  - `grep -P` (Perl regex) - not available in BSD grep
  - `sed -i` without backup extension syntax differences
  - `date` format string differences
  - `wc -l` leading whitespace handling (already handled with `tr -d ' '`)
- **Add portable helper functions** for common operations
- **Test on both macOS and Debian** before marking complete

## Impact

- Affected specs: `k8s-troubleshooter`
- Affected files:
  - `scripts/cluster_assessment.sh` - **PRIMARY** - rewrite template substitution
  - `scripts/cluster_health_check.sh` - audit for compatibility
  - `scripts/pod_diagnostics.sh` - audit for compatibility
  - `scripts/network_debug.sh` - audit for compatibility
  - `scripts/storage_check.sh` - audit for compatibility
  - `scripts/helm_release_debug.sh` - audit for compatibility
