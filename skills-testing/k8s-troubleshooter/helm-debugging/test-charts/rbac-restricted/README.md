# DR-005: RBAC Permission Issues Test Chart

## Purpose

This chart tests detection of RBAC permission issues during deployment.

## Chart Components

Creates a service account with a Role that grants:
- Full access to secrets (get, list, create, update, delete)
- Limited access to configmaps (get, list, create)

## Prerequisites

```bash
kubectl config set-context --current --namespace=helm-test-dryrun

# Create service account with limited permissions (for testing)
kubectl create serviceaccount limited-sa -n helm-test-dryrun
```

## Usage

```bash
# Deploy normally (creates SA with proper RBAC)
helm install test-rbac ./rbac-restricted -n helm-test-dryrun --dry-run=server

# Or test with pre-existing limited SA
helm install test-rbac ./rbac-restricted -n helm-test-dryrun \
  --set serviceAccount.create=false \
  --set serviceAccount.name=limited-sa --dry-run=server
```

## Expected Behavior

- Server-side dry-run typically succeeds (validates chart structure, not runtime SA permissions)
- Actual deployment succeeds
- Runtime failures occur if SA lacks permissions to access resources
- Script shows RBAC-related resources

## Validation

```bash
# Check service account exists
kubectl get sa limited-sa -n helm-test-dryrun

# Check RBAC permissions
kubectl auth can-i create secrets --as=system:serviceaccount:helm-test-dryrun:limited-sa -n helm-test-dryrun

# Check what permissions the chart grants
helm template test-rbac ./rbac-restricted | grep -A 20 "kind.*Role"
```

## Notes

RBAC permission issues are typically not caught by dry-run since they occur at runtime when the pod's service account attempts to access resources.

## Cleanup

```bash
kubectl delete serviceaccount limited-sa -n helm-test-dryrun
```
