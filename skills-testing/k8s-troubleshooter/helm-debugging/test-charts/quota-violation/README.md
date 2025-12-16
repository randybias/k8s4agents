# DR-004: Resource Quota Violations Test Chart

## Purpose

This chart tests detection of resource quota violations during dry-run.

## Failure Mechanism

Requests resources (500Mi memory, 500m CPU) that exceed the test quota (100Mi memory, 100m CPU).

## Prerequisites

```bash
kubectl config set-context --current --namespace=helm-test-dryrun

# Create restrictive quota
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: test-quota
  namespace: helm-test-dryrun
spec:
  hard:
    requests.cpu: "100m"
    requests.memory: "100Mi"
    limits.cpu: "200m"
    limits.memory: "200Mi"
EOF
```

## Usage

```bash
# Attempt to deploy chart that exceeds quota
helm install test-quota ./quota-violation -n helm-test-dryrun --dry-run=server
```

## Expected Behavior

- Server-side dry-run fails
- Quota exceeded error
- Shows requested (500Mi/500m) vs. available (100Mi/100m) resources
- Suggests adjusting requests/limits

## Validation

```bash
# Verify quota exists
kubectl get resourcequota -n helm-test-dryrun

# Verify chart exceeds quota
helm template test-quota ./quota-violation | grep -A 5 "resources:"

# Server rejects due to quota
helm install test-quota ./quota-violation -n helm-test-dryrun --dry-run=server 2>&1 | grep -i "quota\|exceeded"
```

## Cleanup

```bash
kubectl delete resourcequota test-quota -n helm-test-dryrun
```
