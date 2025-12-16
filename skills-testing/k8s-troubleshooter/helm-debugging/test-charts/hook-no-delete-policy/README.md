# HF-007: Hook Delete Policy Issues Test Chart

## Purpose

This chart tests detection of orphaned hooks that should have been deleted but remain because they lack a delete policy.

## Failure Mechanism

Hooks are defined without `helm.sh/hook-delete-policy` annotation, causing them to persist after completion.

## Usage

```bash
# Initial install
helm install test-hook-orphan ./hook-no-delete-policy -n helm-test-hooks

# Wait for completion
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-hooks --timeout=60s

# Upgrade to create more orphaned hooks
helm upgrade test-hook-orphan ./hook-no-delete-policy -n helm-test-hooks --set version=v2
```

## Expected Behavior

- Multiple hook jobs/pods remain after successful execution
- Jobs from both initial install and upgrade are present
- Script lists orphaned hooks
- Hooks are in "Completed" status but not deleted

## Validation

```bash
# Should see multiple completed hook jobs
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook"

# Should see multiple completed hook pods
kubectl get pods -n helm-test-hooks -l "helm.sh/hook"
```
