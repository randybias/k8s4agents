# RS-002: Pending-Install Release Test Chart

## Purpose

This chart tests detection of a release stuck in pending-install state.

## Failure Mechanism

The deployment's container exits immediately with code 1, causing CrashLoopBackOff. The readiness probe never succeeds, keeping the release in pending-install state.

## Usage

```bash
# Deploy (will stay pending)
helm install test-pending-install ./pending-install -n helm-test-states --wait=false

# Wait for state to persist
sleep 30
```

## Expected Behavior

- Release status shows "pending-install"
- Pod is in CrashLoopBackOff
- Container logs show exit with code 1
- Readiness probe fails
- Script warns about pending state

## Validation

```bash
# Verify pending state
helm list -n helm-test-states --pending

# Check pod status
kubectl get pods -n helm-test-states
```
