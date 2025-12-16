# TF-004: Service Not Ready During Tests Test Chart

## Purpose

This chart tests detection when a test runs before the service is ready.

## Failure Mechanism

The deployment has a 60-second `initialDelaySeconds` on its readiness and startup probes. If the test runs immediately after deployment (without waiting), it fails with connection refused because endpoints are not ready.

## Usage

```bash
# Deploy chart with slow-starting service
helm install test-service-not-ready ./test-service-not-ready -n helm-test-tests

# Run test immediately (before service ready) - will fail
helm test test-service-not-ready -n helm-test-tests --logs

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-service-not-ready helm-test-tests --run-tests
```

## Expected Behavior

- Deployment succeeds but pod takes time to be ready
- Test fails with connection refused or timeout
- Service exists but endpoints not ready
- Test logs show connection errors
- Script identifies service readiness issue

## Validation

```bash
# Check service exists
kubectl get svc -n helm-test-tests

# Check endpoints (may be empty initially)
kubectl get endpoints -n helm-test-tests

# Check pod readiness
kubectl get pods -n helm-test-tests -l app=test-app

# Verify test failed with connection error
kubectl logs -n helm-test-tests -l "helm.sh/hook=test" | grep -i "connection\|refused\|timeout"
```

## Notes

To make the test succeed, wait 60+ seconds after deployment before running `helm test`.

## Cleanup

```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-service-not-ready -n helm-test-tests
```
