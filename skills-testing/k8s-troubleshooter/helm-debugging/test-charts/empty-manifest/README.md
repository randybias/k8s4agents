# RS-004: Empty Manifest Test Chart

## Purpose

This chart tests detection of a release with an empty or minimal manifest due to all templates being conditionally disabled.

## Failure Mechanism

All templates are wrapped in `{{- if .Values.enabled }}` conditionals. When deployed with `enabled=false`, no resources are rendered, resulting in an empty manifest.

## Usage

```bash
# Deploy with all templates disabled
helm install test-empty-manifest ./empty-manifest -n helm-test-states --set enabled=false
```

## Expected Behavior

- Release status shows "deployed" but no resources created
- Manifest is empty or only contains comments/whitespace
- No pods exist
- Script warns about empty manifest
- Suggests checking chart conditions

## Validation

```bash
# Verify manifest is empty
helm get manifest test-empty-manifest -n helm-test-states

# Should show no pods
kubectl get pods -n helm-test-states
```
