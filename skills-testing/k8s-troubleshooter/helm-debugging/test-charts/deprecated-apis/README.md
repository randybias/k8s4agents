# CV-005: Deprecated Kubernetes APIs Test Chart

## Purpose

This chart tests detection of deprecated or removed Kubernetes APIs.

## Failure Mechanism

Uses deprecated API versions:
- `apps/v1beta1` for Deployment (removed in Kubernetes 1.16+)
- `extensions/v1beta1` for Ingress (removed in Kubernetes 1.22+)

## Usage

```bash
# Client-side template renders (doesn't validate APIs)
helm template test-deprecated ./deprecated-apis

# Server-side dry-run shows deprecation warnings or errors
helm install test-deprecated ./deprecated-apis -n helm-test-validation --dry-run=server
```

## Expected Behavior

- Client-side template renders successfully
- Server-side dry-run shows deprecation warnings or failures
- On newer clusters (k8s 1.22+), API server rejects the resources
- Clear error message about API version

## Validation

```bash
# Check for deprecated API usage
helm template test-deprecated ./deprecated-apis | grep -i "apiVersion"

# Server-side should warn or fail
helm template test-deprecated ./deprecated-apis | kubectl apply --dry-run=server -f - 2>&1 | grep -i "deprecated\|no.*resource\|unsupported"
```

## Notes

On Kubernetes 1.22+, these APIs are completely removed and will fail. On older clusters, you may see deprecation warnings instead.
