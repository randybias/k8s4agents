# Hook Post-Install Fail Test Chart

## Purpose
This chart tests detection of failing post-install hooks that run after main resources are deployed.

## Failure Mechanism
- Main deployment succeeds and pods start running
- Post-install hook executes after deployment
- Hook fails with exit code 1
- Main application continues running despite hook failure

## Expected Behavior
- Main deployment creates successfully
- Application pods are running
- Post-install hook job fails
- Release may show "deployed" status (varies by Helm version)
- Hook pod logs show "ERROR: Post-installation validation failed!"
- `helm_release_debug.sh` should identify the post-install hook failure

## Test Usage
```bash
helm install test-post-install-fail ./hook-post-install-fail -n helm-test-hooks
```

## Cleanup
```bash
helm uninstall test-post-install-fail -n helm-test-hooks
kubectl delete jobs -n helm-test-hooks -l app=test-post-install-fail
```
