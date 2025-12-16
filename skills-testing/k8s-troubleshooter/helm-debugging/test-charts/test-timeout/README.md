# TF-002: Test Pod Timeout Test Chart

## Purpose

This chart tests detection when a test pod times out.

## Failure Mechanism

The test pod sleeps for 120 seconds before attempting the actual test. When run with `helm test --timeout 30s`, the test times out before completion.

## Usage

```bash
# Deploy chart successfully
helm install test-timeout-test ./test-timeout -n helm-test-tests

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-tests --timeout=60s

# Run helm test with short timeout (will timeout)
helm test test-timeout-test -n helm-test-tests --timeout 30s

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-timeout-test helm-test-tests --run-tests
```

## Expected Behavior

- App deploys successfully
- Test times out before completion
- Helm test command returns timeout error
- Test pod may still be running
- Script identifies timeout issue

## Validation

```bash
# Check test pod status
kubectl get pods -n helm-test-tests -l "helm.sh/hook=test"

# Check test pod logs (may show incomplete test)
kubectl logs -n helm-test-tests -l "helm.sh/hook=test"
```

## Cleanup

```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-timeout-test -n helm-test-tests
```
