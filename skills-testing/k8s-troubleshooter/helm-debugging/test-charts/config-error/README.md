# OS-003: Configuration Errors Test Chart

## Purpose

This chart tests detection of configuration errors that cause application crashes.

## Failure Mechanism

The ConfigMap contains invalid configuration values:
- `logLevel: INVALID_LOG_LEVEL` (invalid enum value)
- `maxConnections: "not-a-number"` (should be integer)
- `apiEndpoint: ""` (empty required field)

The application container validates these on startup and exits with code 1, causing CrashLoopBackOff.

## Usage

```bash
# Deploy chart with invalid configuration
helm install test-config-error ./config-error -n helm-test-states

# Wait for pods to fail
sleep 30

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-config-error helm-test-states
```

## Expected Behavior

- Release shows "deployed"
- Pods are in CrashLoopBackOff
- Pod logs show configuration validation errors
- ConfigMap exists but has invalid values
- Script identifies pod failures and shows relevant logs

## Validation

```bash
# Verify pods crashing
kubectl get pods -n helm-test-states -l app=test-app

# Check pod logs for config errors
kubectl logs -n helm-test-states -l app=test-app | grep -i "config\|error\|invalid"

# Verify ConfigMap exists with bad values
kubectl get configmap -n helm-test-states
kubectl describe configmap config-error-config -n helm-test-states
```

## Cleanup

```bash
helm uninstall test-config-error -n helm-test-states
kubectl delete pods -n helm-test-states --all
```

## Notes

This represents a common real-world scenario where the chart deploys successfully but the application fails at runtime due to configuration issues.
