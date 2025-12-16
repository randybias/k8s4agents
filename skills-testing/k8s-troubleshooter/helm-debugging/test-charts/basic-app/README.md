# RS-005: Basic App Test Chart (Missing Resources)

## Purpose

This is a basic working chart used to test detection when resources are deleted manually outside of Helm.

## Usage

```bash
# Deploy successfully
helm install test-missing-resources ./basic-app -n helm-test-states

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-states --timeout=60s

# Manually delete deployment (simulating out-of-band deletion)
kubectl delete deployment -n helm-test-states -l app=test-app

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-missing-resources helm-test-states
```

## Expected Behavior

- Release status shows "deployed" (Helm doesn't track live state)
- Manifest contains resources that don't exist in cluster
- Script reports discrepancy
- Shows NotFound errors when checking resources

## Validation

```bash
# Helm thinks it's deployed
helm status test-missing-resources -n helm-test-states

# But resources don't exist
kubectl get deployment -n helm-test-states | grep test-app || echo "Not found"
```
