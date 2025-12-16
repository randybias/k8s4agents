# Hook Pre-Install Fail Test Chart

## Purpose
This chart is designed to test detection of failing pre-install hooks.

## Failure Mechanism
- The pre-install hook job executes a script that always exits with code 1
- This simulates a pre-installation validation failure
- The main deployment should never be created because the hook blocks installation

## Expected Behavior
- `helm install` command fails
- Release shows "pending-install" or "failed" status
- Hook job shows failed status
- Hook pod logs show "ERROR: Pre-installation validation failed!"
- Main application pods are never created
- `helm_release_debug.sh` should identify the pre-install hook as the failure point

## Test Usage
```bash
helm install test-pre-install-fail ./hook-pre-install-fail -n helm-test-hooks
```

## Cleanup
```bash
helm uninstall test-pre-install-fail -n helm-test-hooks
kubectl delete jobs -n helm-test-hooks -l app=test-pre-install-fail
```
