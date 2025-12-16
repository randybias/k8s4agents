# HF-005: Stuck/Hanging Hook Test Chart

## Purpose

This chart tests detection of a hook that runs indefinitely without completing.

## Failure Mechanism

The pre-install hook runs an infinite loop without an activeDeadlineSeconds, causing it to hang forever.

## Usage

```bash
# Deploy (will hang)
helm install test-stuck-hook ./hook-stuck -n helm-test-hooks

# Wait 60+ seconds, then check
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=pre-install"
```

## Expected Behavior

- Release status shows "pending-install"
- Hook job shows active/running
- Hook pod is running but never completes
- No error events (just running indefinitely)

## Cleanup

```bash
# Must force delete stuck resources
kubectl delete jobs -n helm-test-hooks --all --force --grace-period=0
helm uninstall test-stuck-hook -n helm-test-hooks
```
