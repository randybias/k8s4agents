# RS-003: Pending-Upgrade Release Test Chart

## Purpose

This chart tests detection of a release stuck in pending-upgrade state.

## Failure Mechanism

When upgraded with `failUpgrade=true`, the deployment uses a non-existent image, causing ImagePullBackOff and leaving the release in pending-upgrade state.

## Usage

```bash
# Initial deployment (succeeds)
helm install test-pending-upgrade ./pending-upgrade -n helm-test-states --set version=v1

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-states --timeout=60s

# Upgrade with failing image
helm upgrade test-pending-upgrade ./pending-upgrade -n helm-test-states \
  --set version=v2 --set failUpgrade=true --wait=false

# Wait for stuck state
sleep 30
```

## Expected Behavior

- Release status shows "pending-upgrade"
- History shows revision 1 deployed, revision 2 pending
- New pods show ImagePullBackOff
- Old version may still be running
- Script warns about stuck upgrade

## Validation

```bash
# Verify pending-upgrade state
helm list -n helm-test-states --pending

# Check history
helm history test-pending-upgrade -n helm-test-states | grep pending
```
