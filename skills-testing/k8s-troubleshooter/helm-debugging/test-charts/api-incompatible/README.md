# DR-003: API Compatibility Issues Test Chart

## Purpose

This chart tests detection of Kubernetes API version incompatibilities.

## Failure Mechanism

Uses `batch/v2alpha1` for CronJob, which was removed in Kubernetes 1.21 (should use `batch/v1` or `batch/v1beta1`).

## Usage

```bash
# Attempt to deploy chart with incompatible API version
helm install test-api-compat ./api-incompatible -n helm-test-dryrun --dry-run=server
```

## Expected Behavior

- Server-side validation fails on Kubernetes 1.21+
- API version not supported by cluster
- Error message shows "no matches for kind" or "unsupported API version"
- Suggests updating chart API versions

## Validation

```bash
# Check cluster API versions
kubectl api-versions | grep -i batch

# Verify chart uses unsupported version
helm template test-api-compat ./api-incompatible | grep apiVersion

# Server rejects on modern clusters
helm install test-api-compat ./api-incompatible -n helm-test-dryrun --dry-run=server 2>&1 | grep -i "no.*matches\|unsupported"
```

## Notes

On Kubernetes 1.20 and older, batch/v2alpha1 may still be available. Test on Kubernetes 1.21+ for guaranteed failure.
