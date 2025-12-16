# HF-004: Post-Upgrade Hook Failure Test Chart

## Purpose

This chart tests detection of a post-upgrade hook that fails after upgrade completes.

## Failure Mechanism

When upgraded with `failPostUpgrade=true`, the post-upgrade hook exits with code 1 after the new version is deployed.

## Usage

```bash
# Initial deployment
helm install test-post-upgrade ./hook-post-upgrade-fail -n helm-test-hooks --set version=v1 --set failPostUpgrade=false

# Upgrade with failing post-hook
helm upgrade test-post-upgrade ./hook-post-upgrade-fail -n helm-test-hooks --set version=v2 --set failPostUpgrade=true
```

## Expected Behavior

- Release may show "deployed" status (main resources succeeded)
- New version is running
- Post-upgrade hook job shows failed status
- Hook logs show the error
