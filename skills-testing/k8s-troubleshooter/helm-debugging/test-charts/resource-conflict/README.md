# OS-001: Resource Name Conflicts Test Chart

## Purpose

This chart tests detection when resource names conflict with existing resources.

## Failure Mechanism

The chart creates resources with hardcoded names ("conflict-test"). If a deployment or service with this name already exists in the namespace, installation fails.

## Prerequisites

```bash
kubectl config set-context --current --namespace=helm-test-validation

# Create a conflicting resource manually
kubectl create deployment conflict-test --image=nginx -n helm-test-validation
```

## Usage

```bash
# Attempt to install chart with same resource name (will fail)
helm install test-conflict ./resource-conflict -n helm-test-validation
```

## Expected Behavior

- Installation fails immediately
- Error shows "resource already exists"
- Helm cannot take ownership of existing resource
- Clear conflict message
- Release may not be created

## Validation

```bash
# Verify existing resource
kubectl get deployment conflict-test -n helm-test-validation

# Verify helm install failed
helm list -n helm-test-validation --all | grep test-conflict || echo "Release not created"

# Check error message
helm install test-conflict ./resource-conflict -n helm-test-validation 2>&1 | grep -i "already exists\|conflict"
```

## Cleanup

```bash
kubectl delete deployment conflict-test -n helm-test-validation
kubectl delete service conflict-test -n helm-test-validation 2>/dev/null || true
helm uninstall test-conflict -n helm-test-validation 2>/dev/null || true
```

## Notes

This demonstrates why using Chart.Name or Release.Name in resource names is preferable to hardcoded names.
