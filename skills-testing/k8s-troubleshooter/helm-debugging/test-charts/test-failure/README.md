# Test Failure Test Chart

## Purpose
This chart tests detection of failing Helm tests.

## Failure Mechanism
- Application deploys successfully
- Service is created and accessible
- Helm test tries to access a non-existent endpoint
- Test pod exits with failure code

## Expected Behavior
- `helm install` succeeds
- Application pods run normally
- Service is available
- `helm test` command fails
- Test pod shows failed/error status
- Test logs show "Test FAILED: Endpoint returned error or does not exist"
- `helm_release_debug.sh --run-tests` should detect test failure

## Test Usage
```bash
# Install the chart
helm install test-fail-test ./test-failure -n helm-test-tests

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-tests --timeout=60s

# Run tests (should fail)
helm test test-fail-test -n helm-test-tests --logs
```

## Cleanup
```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-fail-test -n helm-test-tests
```
