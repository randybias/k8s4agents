# HF-006: Hook Timeout Test Chart

## Purpose

This chart tests detection of a hook that times out due to activeDeadlineSeconds.

## Failure Mechanism

The pre-install hook sleeps for 120 seconds but has `activeDeadlineSeconds: 30`, causing it to be killed by Kubernetes after 30 seconds.

## Usage

```bash
# Deploy (hook will timeout)
helm install test-hook-timeout ./hook-timeout -n helm-test-hooks

# Wait 40 seconds for timeout
sleep 40
```

## Expected Behavior

- Release status shows "failed" or "pending-install"
- Hook job shows failed due to DeadlineExceeded
- Pod shows status "DeadlineExceeded"
- Events show "Job was active longer than specified deadline"
- Script identifies timeout as cause

## Validation

```bash
# Verify timeout occurred
kubectl describe job -n helm-test-hooks -l "helm.sh/hook=pre-install" | grep -i deadline
kubectl get pod -n helm-test-hooks -l "helm.sh/hook=pre-install" -o jsonpath='{.items[0].status.reason}'
```
