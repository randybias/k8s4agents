# Helm Debug Test Charts

This directory contains sample Helm charts with intentional failures designed to test the `helm_release_debug.sh` script and related Helm debugging procedures.

## Overview

Each chart in this directory induces a specific failure scenario that the debug script should detect and diagnose. These charts are used by the automated test suite (`run-helm-debug-tests.sh`) and can also be used for manual testing.

## Available Test Charts

### Hook Failures

| Chart | Failure Type | Description |
|-------|--------------|-------------|
| `hook-pre-install-fail` | Pre-install hook failure | Hook exits with error code 1, blocks installation |
| `hook-post-install-fail` | Post-install hook failure | Main app deploys, post-hook fails |
| `hook-pre-upgrade-fail` | Pre-upgrade hook failure | Upgrade blocked by failing pre-upgrade hook |
| `hook-post-upgrade-fail` | Post-upgrade hook failure | Upgrade succeeds, post-hook fails |
| `hook-stuck` | Stuck/hanging hook | Hook runs indefinitely without completing |
| `hook-timeout` | Hook timeout | Hook exceeds activeDeadlineSeconds |
| `hook-no-delete-policy` | Orphaned hooks | Hooks remain after completion (no delete policy) |

### Release State Issues

| Chart | Failure Type | Description |
|-------|--------------|-------------|
| `failed-release` | Failed release | ImagePullBackOff causes deployment failure |
| `pending-install` | Pending-install state | Resources don't become ready |
| `pending-upgrade` | Pending-upgrade state | Upgrade gets stuck |
| `empty-manifest` | Empty manifest | All templates conditional and disabled |
| `basic-app` | Missing resources test | Deploy then manually delete resources |

### Chart Validation Issues

| Chart | Failure Type | Description |
|-------|--------------|-------------|
| `lint-fail-chart-yaml` | Invalid Chart.yaml | Missing required version field |
| `lint-fail-syntax` | YAML syntax errors | Invalid indentation in templates |
| `template-fail` | Template rendering errors | Undefined variables, nil pointers |
| `missing-required-values` | Missing values | Required values not provided |
| `deprecated-apis` | Deprecated APIs | Uses removed Kubernetes API versions |
| `yaml-syntax-error` | YAML syntax | Invalid YAML structure |

### Dry-Run Issues

| Chart | Failure Type | Description |
|-------|--------------|-------------|
| `client-dryrun-fail` | Client-side validation | Invalid YAML caught by client |
| `server-dryrun-fail` | Server-side validation | API compatibility issues |
| `api-incompatible` | API version mismatch | Unsupported API version |
| `quota-violation` | Resource quota | Exceeds namespace quotas |
| `rbac-restricted` | RBAC issues | Service account lacks permissions |

### Test Failures

| Chart | Failure Type | Description |
|-------|--------------|-------------|
| `test-failure` | Helm test fails | Test pod exits with error |
| `test-timeout` | Test timeout | Test runs too long |
| `test-imagepull` | ImagePullBackOff | Test image doesn't exist |
| `test-service-not-ready` | Service not ready | Test runs before service ready |

### Other Scenarios

| Chart | Failure Type | Description |
|-------|--------------|-------------|
| `resource-conflict` | Name conflict | Resource already exists |
| `db-migration-fail` | Migration failure | Database migration hook fails |
| `config-error` | Config error | Invalid configuration causes crashes |

## Usage

### Manual Testing

```bash
# Navigate to test charts directory
cd /Users/rbias/code/k8s4agents/scratch/test-charts

# Test a specific chart
helm install test-name ./chart-name -n namespace-name

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-name namespace-name

# Cleanup
helm uninstall test-name -n namespace-name
kubectl delete jobs,pods -n namespace-name --all
```

### Automated Testing

```bash
# Run all tests
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh

# Run specific category
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh --category hooks

# Run specific test
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh --test HF-001
```

## Chart Structure

Each test chart follows this structure:

```
chart-name/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── README.md              # Chart-specific documentation
└── templates/
    ├── deployment.yaml    # Main application (if applicable)
    ├── service.yaml       # Service (if applicable)
    ├── hooks/             # Hook resources (if applicable)
    └── tests/             # Test resources (if applicable)
```

## Creating New Test Charts

When adding a new test chart:

1. Create chart directory with standard structure
2. Include descriptive README.md explaining:
   - Purpose of the test
   - Failure mechanism
   - Expected behavior
   - Usage instructions
   - Cleanup steps
3. Add chart to this index
4. Update test plan document
5. Add test implementation to `run-helm-debug-tests.sh`

## Test Chart Requirements

All test charts must:
- Be self-contained (no external dependencies)
- Have clear, documented failure mechanisms
- Include README with usage instructions
- Use standard Helm chart structure
- Clean up properly (appropriate delete policies)
- Be reproducible across different clusters

## Common Patterns

### Failing Hook Pattern

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-hook
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hook
        image: busybox
        command: ["/bin/sh", "-c", "exit 1"]
```

### Failing Test Pattern

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-test
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  containers:
  - name: test
    image: curlimages/curl
    command:
    - sh
    - -c
    - |
      # Test logic that fails
      exit 1
  restartPolicy: Never
```

### ImagePullBackOff Pattern

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: nonexistent.registry.com/image:tag
        imagePullPolicy: Always
```

## Troubleshooting Test Charts

### Chart Won't Deploy

```bash
# Validate chart structure
helm lint ./chart-name

# Check template rendering
helm template test ./chart-name

# Dry-run
helm install test ./chart-name --dry-run --debug
```

### Cleanup Issues

```bash
# Force delete resources
kubectl delete namespace test-namespace --force --grace-period=0

# Remove stuck finalizers
kubectl patch namespace test-namespace -p '{"metadata":{"finalizers":null}}'
```

### Test Not Failing as Expected

1. Check chart README for prerequisites
2. Verify values.yaml settings
3. Check if cluster version affects behavior
4. Review events and logs for actual error

## Maintenance

### Regular Tasks

- Verify all charts work with current Kubernetes/Helm versions
- Update deprecated API versions (while keeping deprecated-apis chart)
- Test charts periodically to ensure reproducibility
- Update documentation as scenarios evolve

### Version Compatibility

These charts are tested with:
- Kubernetes 1.20+
- Helm 3.8+

Specific API versions may need adjustment for newer clusters.

## Related Documentation

- [Helm Debug Test Plan](/Users/rbias/code/k8s4agents/scratch/helm-debug-test-plan.md)
- [Automated Test Script](/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh)
- [Helm Debugging Reference](/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/references/helm-debugging.md)
- [helm_release_debug.sh Script](/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh)

## Contributing

When adding new failure scenarios:
1. Create the test chart
2. Document in chart README
3. Add to this index
4. Update test plan
5. Implement automated test
6. Verify test passes/fails as expected

---

**Last Updated**: 2025-12-16
**Maintainer**: K8s4Agents Project
