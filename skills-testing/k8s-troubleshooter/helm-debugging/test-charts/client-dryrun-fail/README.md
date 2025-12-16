# DR-001: Client-Side Dry-Run Failures Test Chart

## Purpose

This chart tests detection of issues caught by client-side dry-run validation.

## Failure Mechanism

Contains multiple validation errors:
- Invalid label name with special characters: `invalid-label-$%^&*`
- Invalid containerPort type (string "eighty" instead of integer)

## Usage

```bash
# Attempt client-side dry-run (will fail)
helm install test-client-dryrun ./client-dryrun-fail -n helm-test-dryrun --dry-run

# Run debug script with dry-run option
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-client-dryrun helm-test-dryrun \
  --chart ./client-dryrun-fail --run-dry-run
```

## Expected Behavior

- Client-side dry-run fails
- YAML validation error reported
- Does not contact Kubernetes API server
- Script shows client-side dry-run failure

## Validation

```bash
# Verify client-side error
helm install test-client-dryrun ./client-dryrun-fail -n helm-test-dryrun --dry-run 2>&1 | grep -i error
```
