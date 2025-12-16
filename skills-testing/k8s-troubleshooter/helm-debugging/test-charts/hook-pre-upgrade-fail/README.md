# HF-003: Pre-Upgrade Hook Failure Test Chart

## Purpose

This chart tests detection of a failing pre-upgrade hook that blocks chart upgrades.

## Failure Mechanism

When deployed with `failPreUpgrade=true`, the pre-upgrade hook exits with code 1, preventing the upgrade from proceeding.

## Usage

```bash
# Initial deployment (hook disabled)
helm install test-pre-upgrade ./hook-pre-upgrade-fail -n helm-test-hooks --set failPreUpgrade=false

# Upgrade with failing hook
helm upgrade test-pre-upgrade ./hook-pre-upgrade-fail -n helm-test-hooks --set failPreUpgrade=true
```

## Expected Behavior

- Release status shows "pending-upgrade" or "failed"
- Pre-upgrade hook job shows failed status
- Previous version continues running
- Main upgrade is blocked
