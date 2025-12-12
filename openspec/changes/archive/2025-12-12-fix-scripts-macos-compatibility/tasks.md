# Tasks: Fix Scripts macOS Compatibility

## 1. Fix cluster_assessment.sh Template Substitution

- [x] 1.1 Rewrite `generate_report()` to build markdown content inline instead of using sed template substitution
- [x] 1.2 Replace all `sed -i.bak "s|{{VAR}}|$value|g"` calls with direct heredoc/printf content generation
- [x] 1.3 Remove template placeholder approach entirely - generate sections dynamically
- [x] 1.4 Test on macOS to verify fix

## 2. Audit Other Scripts for BSD/GNU Incompatibilities

- [x] 2.1 Review `cluster_health_check.sh` for non-portable constructs - Fixed `set -o pipefail` interactions with grep
- [x] 2.2 Review `pod_diagnostics.sh` for non-portable constructs - No issues found
- [x] 2.3 Review `network_debug.sh` for non-portable constructs - No issues found
- [x] 2.4 Review `storage_check.sh` for non-portable constructs - No issues found
- [x] 2.5 Review `helm_release_debug.sh` for non-portable constructs - No issues found

## 3. Add Portable Helper Functions (if needed)

- [x] 3.1 Add `count_lines()` helper function that handles empty input and wc whitespace
- [x] 3.2 Add `grep_count()` helper function that returns 0 on no matches instead of failing
- [x] 3.3 Document portability in script headers

## 4. Validation

- [x] 4.1 Test all scripts on macOS (local laptop) - All pass
- [x] 4.2 Test all scripts on Debian (remote box - k0s cluster) - All pass
- [x] 4.3 Verify cluster_assessment.sh generates complete report - Verified on both platforms
- [x] 4.4 Verify cluster_health_check.sh completes without errors - Verified on both platforms
