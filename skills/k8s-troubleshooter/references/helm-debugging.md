# Helm Debugging and Troubleshooting

Comprehensive guide for diagnosing Helm chart issues, release failures, and upgrade problems.

## Table of Contents

- [Helm Basics](#helm-basics)
- [Chart Validation](#chart-validation)
- [Release Troubleshooting](#release-troubleshooting)
- [Upgrade and Rollback Issues](#upgrade-and-rollback-issues)
- [Stuck Releases](#stuck-releases)
- [Secret and State Management](#secret-and-state-management)
- [Hook Failures](#hook-failures)
- [Values and Templating](#values-and-templating)

## Helm Basics

### Helm Architecture

**Components**:
- **Chart**: Package of Kubernetes manifests
- **Release**: Installed instance of a chart
- **Repository**: Collection of charts
- **Values**: Configuration parameters for chart

### Initial Investigation

```bash
# Check Helm version
helm version

# List releases
helm list -n <NAMESPACE>
helm list --all-namespaces

# Get release status
helm status <RELEASE_NAME> -n <NAMESPACE>

# Get release history
helm history <RELEASE_NAME> -n <NAMESPACE>

# Show release values
helm get values <RELEASE_NAME> -n <NAMESPACE>

# Show release manifest
helm get manifest <RELEASE_NAME> -n <NAMESPACE>
```

## Chart Validation

### Pre-Installation Validation

```bash
# Lint chart
helm lint <CHART_PATH>

# Lint with values file
helm lint <CHART_PATH> -f <VALUES_FILE>

# Check for deprecated APIs
helm lint <CHART_PATH> --strict
```

### Template Rendering

```bash
# Render templates without installing
helm template <RELEASE_NAME> <CHART_PATH>

# Render with values file
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE>

# Render with inline values
helm template <RELEASE_NAME> <CHART_PATH> --set key=value

# Output to file for inspection
helm template <RELEASE_NAME> <CHART_PATH> > rendered-manifest.yaml

# Check specific template
helm template <RELEASE_NAME> <CHART_PATH> -s templates/<TEMPLATE_FILE>
```

### Dry-Run Installation

```bash
# Dry-run install
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run --debug

# Dry-run upgrade
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run --debug

# Dry-run with values
helm upgrade --install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> \
  -f <VALUES_FILE> --dry-run --debug
```

### Common Validation Errors

**Invalid YAML syntax**:
```bash
# Lint will catch syntax errors
helm lint <CHART_PATH>

# Validate rendered YAML
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=client -f -
```

**Missing required values**:
```bash
# Check Chart.yaml for required values
cat <CHART_PATH>/Chart.yaml

# Check values.yaml for defaults
cat <CHART_PATH>/values.yaml

# Validate with your values
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE> --validate
```

**Deprecated Kubernetes APIs**:
```bash
# Check for API version issues
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=server -f -

# Use kubectl convert for API migrations (if available)
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl convert -f -
```

## Release Troubleshooting

### Release Status Investigation

```bash
# Get detailed release status
helm status <RELEASE_NAME> -n <NAMESPACE> --show-desc

# Get release info
helm get all <RELEASE_NAME> -n <NAMESPACE>

# Get release notes
helm get notes <RELEASE_NAME> -n <NAMESPACE>

# Check release resources
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl get -f -

# Check resource status
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl describe -f -
```

### Release States

| State | Meaning | Action |
|-------|---------|--------|
| deployed | Successfully installed | Normal operation |
| failed | Installation/upgrade failed | Check logs, fix issues, retry or rollback |
| pending-install | Installation in progress | Wait or investigate if stuck |
| pending-upgrade | Upgrade in progress | Wait or investigate if stuck |
| pending-rollback | Rollback in progress | Wait |
| uninstalling | Uninstallation in progress | Wait |
| superseded | Replaced by newer revision | Historical record |

### Failed Release Investigation

```bash
# Get failed release details
helm history <RELEASE_NAME> -n <NAMESPACE>

# Get specific revision manifest
helm get manifest <RELEASE_NAME> -n <NAMESPACE> --revision <REVISION>

# Get failed revision values
helm get values <RELEASE_NAME> -n <NAMESPACE> --revision <REVISION>

# Check Kubernetes events
kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp' | tail -50

# Check deployed resources
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl get -f - -o wide
```

## Upgrade and Rollback Issues

### Upgrade Investigation

```bash
# Test upgrade with dry-run
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run --debug

# Upgrade with reuse of values
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --reuse-values

# Upgrade with reset values
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --reset-values

# Upgrade with wait (blocks until ready)
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --wait --timeout 10m

# Upgrade with atomic (auto-rollback on failure)
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --atomic --timeout 10m
```

### Rollback

```bash
# List release history
helm history <RELEASE_NAME> -n <NAMESPACE>

# Rollback to previous revision
helm rollback <RELEASE_NAME> -n <NAMESPACE>

# Rollback to specific revision
helm rollback <RELEASE_NAME> <REVISION> -n <NAMESPACE>

# Rollback with wait
helm rollback <RELEASE_NAME> -n <NAMESPACE> --wait --timeout 5m

# Rollback with cleanup on fail
helm rollback <RELEASE_NAME> -n <NAMESPACE> --cleanup-on-fail
```

### Common Upgrade Issues

**Values lost during upgrade**:
```bash
# Always use --reuse-values or explicitly provide values
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --reuse-values -f <NEW_VALUES>

# Compare current values
helm get values <RELEASE_NAME> -n <NAMESPACE> > current-values.yaml
```

**Resource conflicts**:
```bash
# Check for resources managed outside Helm
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl get -f - -o yaml | grep -A 5 "ownerReferences"

# Force upgrade (use with caution!)
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --force
```

**Timeout during upgrade**:
```bash
# Increase timeout
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --timeout 15m

# Disable wait if not needed
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --wait=false

# Check pod status during upgrade
kubectl get pods -n <NAMESPACE> -w
```

## Stuck Releases

### Pending-Upgrade State

**Diagnosis**:
```bash
# Check release status
helm list -n <NAMESPACE> --all

# Check for pending operations
helm history <RELEASE_NAME> -n <NAMESPACE> | grep pending

# Check release secrets
kubectl get secrets -n <NAMESPACE> -l owner=helm,name=<RELEASE_NAME>

# Check latest release secret
kubectl get secret -n <NAMESPACE> \
  sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -o yaml
```

**Recovery**:
```bash
# Option 1: Wait longer (if deployment actually progressing)
helm history <RELEASE_NAME> -n <NAMESPACE>

# Option 2: Rollback to last deployed version
helm rollback <RELEASE_NAME> -n <NAMESPACE>

# Option 3: Force upgrade
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --force --timeout 10m

# Option 4: Manual secret cleanup (last resort)
# First backup the secret
kubectl get secret sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -n <NAMESPACE> -o yaml > backup.yaml
# Then delete pending release secret
kubectl delete secret sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -n <NAMESPACE>
```

### Pending-Install State

```bash
# Check install status
helm list -n <NAMESPACE> --pending

# Check what's blocking
kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp'

# Option 1: Uninstall and retry
helm uninstall <RELEASE_NAME> -n <NAMESPACE>
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE>

# Option 2: Keep history and retry
helm uninstall <RELEASE_NAME> -n <NAMESPACE> --keep-history
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE>
```

## Secret and State Management

### Helm Secrets Investigation

```bash
# List Helm secrets
kubectl get secrets -n <NAMESPACE> -l owner=helm

# List secrets for specific release
kubectl get secrets -n <NAMESPACE> -l owner=helm,name=<RELEASE_NAME>

# Get specific release version secret
kubectl get secret sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -n <NAMESPACE>

# Decode release data (base64 + gzip)
kubectl get secret sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -n <NAMESPACE> \
  -o jsonpath='{.data.release}' | base64 -d | gunzip | jq
```

### Secret Cleanup

```bash
# List all revisions
kubectl get secrets -n <NAMESPACE> -l owner=helm,name=<RELEASE_NAME> \
  --sort-by=.metadata.creationTimestamp

# Delete old revision secrets (keep recent ones)
# Be careful! This removes rollback ability
kubectl delete secret sh.helm.release.v1.<RELEASE_NAME>.v<OLD_REVISION> -n <NAMESPACE>

# Limit history (keeps last N revisions)
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --history-max 5
```

### Corrupted Release State

```bash
# Check for corrupted secrets
kubectl get secret sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -n <NAMESPACE> -o yaml

# Try to decode and validate
kubectl get secret sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -n <NAMESPACE> \
  -o jsonpath='{.data.release}' | base64 -d | gunzip > /dev/null

# If corrupted, delete and recreate
kubectl delete secret sh.helm.release.v1.<RELEASE_NAME>.v<REVISION> -n <NAMESPACE>
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --force
```

## Hook Failures

### Helm Hooks

**Hook Types**:
- `pre-install`: Before install
- `post-install`: After install
- `pre-delete`: Before delete
- `post-delete`: After delete
- `pre-upgrade`: Before upgrade
- `post-upgrade`: After upgrade
- `pre-rollback`: Before rollback
- `post-rollback`: After rollback
- `test`: For `helm test`

### Hook Investigation

```bash
# List hooks in chart
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | grep -A 5 "helm.sh/hook"

# Get hook resources
kubectl get jobs,pods -n <NAMESPACE> -l "app.kubernetes.io/managed-by=Helm"

# Check hook job status
kubectl get job <HOOK_JOB_NAME> -n <NAMESPACE>

# Check hook pod logs
kubectl logs <HOOK_POD_NAME> -n <NAMESPACE>

# Check hook failure events
kubectl describe pod <HOOK_POD_NAME> -n <NAMESPACE>
```

### Hook Policies

```yaml
# helm.sh/hook-delete-policy annotations:
# - before-hook-creation: Delete previous hook before new one
# - hook-succeeded: Delete after successful execution
# - hook-failed: Delete after failed execution
```

### Hook Troubleshooting

```bash
# Check hook deletion policy
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | grep -A 2 "hook-delete-policy"

# Manual hook cleanup (if hook failed and not deleted)
kubectl delete job <HOOK_JOB_NAME> -n <NAMESPACE>
kubectl delete pod <HOOK_POD_NAME> -n <NAMESPACE>

# Disable hooks during upgrade (emergency)
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --no-hooks

# Test hooks separately
helm template <RELEASE_NAME> <CHART_PATH> -s templates/<HOOK_TEMPLATE> | kubectl apply -f -
```

## Values and Templating

### Values Investigation

```bash
# Show default values
helm show values <CHART_PATH>

# Show current release values
helm get values <RELEASE_NAME> -n <NAMESPACE>

# Show all values (including defaults)
helm get values <RELEASE_NAME> -n <NAMESPACE> --all

# Compare values between revisions
helm get values <RELEASE_NAME> -n <NAMESPACE> --revision <REV1> > values-rev1.yaml
helm get values <RELEASE_NAME> -n <NAMESPACE> --revision <REV2> > values-rev2.yaml
diff values-rev1.yaml values-rev2.yaml
```

### Template Functions and Debugging

```bash
# Debug template rendering
helm template <RELEASE_NAME> <CHART_PATH> --debug

# Show only specific template
helm template <RELEASE_NAME> <CHART_PATH> -s templates/deployment.yaml

# Test with different values
helm template <RELEASE_NAME> <CHART_PATH> --set image.tag=debug --set replicaCount=1

# Validate template output
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=client -f -
```

### Common Template Errors

**Undefined variable**:
```bash
# Check template syntax
helm template <RELEASE_NAME> <CHART_PATH> --debug 2>&1 | grep "undefined"

# Provide missing value
helm template <RELEASE_NAME> <CHART_PATH> --set missingVar=value
```

**Type mismatch**:
```bash
# Check value types in values.yaml
cat <CHART_PATH>/values.yaml

# Ensure correct type when setting
helm template <RELEASE_NAME> <CHART_PATH> --set "ports[0]=8080" --set "enabled=true"
```

**Invalid YAML indentation**:
```bash
# Validate YAML
helm template <RELEASE_NAME> <CHART_PATH> | yamllint -

# Check specific resource
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=client -f -
```

## Testing and Validation

### Helm Test

```bash
# Run tests
helm test <RELEASE_NAME> -n <NAMESPACE>

# Run tests with logs
helm test <RELEASE_NAME> -n <NAMESPACE> --logs

# Run specific test
helm test <RELEASE_NAME> -n <NAMESPACE> --filter name=<TEST_NAME>

# Check test pod logs
kubectl logs <TEST_POD_NAME> -n <NAMESPACE>
```

### Pre-Deployment Validation

```bash
# 1. Lint chart
helm lint <CHART_PATH>

# 2. Template and validate YAML
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE> | kubectl apply --dry-run=server -f -

# 3. Dry-run install
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> -f <VALUES_FILE> --dry-run --debug

# 4. Check for deprecated APIs
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=server -f - 2>&1 | grep -i deprecated
```

## Dependency Management

### Chart Dependencies

```bash
# List chart dependencies
helm dependency list <CHART_PATH>

# Update dependencies
helm dependency update <CHART_PATH>

# Build dependencies
helm dependency build <CHART_PATH>

# Check Chart.yaml for dependencies
cat <CHART_PATH>/Chart.yaml | grep -A 10 dependencies

# Check charts directory
ls -la <CHART_PATH>/charts/
```

### Dependency Issues

```bash
# Missing dependency
helm dependency update <CHART_PATH>

# Outdated dependency
rm -rf <CHART_PATH>/charts/*.tgz
helm dependency build <CHART_PATH>

# Dependency version conflict
# Check Chart.lock
cat <CHART_PATH>/Chart.lock

# Update specific dependency
helm repo update
helm dependency update <CHART_PATH>
```

## Best Practices

1. **Always use --dry-run first** - Catch errors before applying
2. **Use --atomic for upgrades** - Auto-rollback on failure
3. **Set appropriate timeouts** - Prevent indefinite hangs
4. **Maintain values files** - Don't rely on --set for production
5. **Test charts before release** - Use helm lint and helm test
6. **Use semantic versioning** - For chart and app versions
7. **Document values** - Clear descriptions in values.yaml
8. **Limit history** - Use --history-max to prevent secret bloat
9. **Monitor hook execution** - Hooks can fail silently
10. **Back up release state** - Export important release configs

## Troubleshooting Checklist

When debugging Helm issues:

1. ✓ Check Helm version compatibility
2. ✓ Lint chart
3. ✓ Validate templates with dry-run
4. ✓ Check release status and history
5. ✓ Review release values
6. ✓ Check deployed resources
7. ✓ Investigate hooks if present
8. ✓ Check Kubernetes events
9. ✓ Review pod logs
10. ✓ Validate dependencies

## Emergency Recovery

### Complete Release Reset

```bash
# WARNING: This removes all release history!

# 1. Backup release state
helm get values <RELEASE_NAME> -n <NAMESPACE> > backup-values.yaml
helm get manifest <RELEASE_NAME> -n <NAMESPACE> > backup-manifest.yaml

# 2. Delete release secrets
kubectl delete secrets -n <NAMESPACE> -l owner=helm,name=<RELEASE_NAME>

# 3. Clean up resources (if needed)
kubectl delete -n <NAMESPACE> -f backup-manifest.yaml

# 4. Reinstall
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> -f backup-values.yaml
```

### Orphaned Resources

```bash
# Find resources not in current manifest
helm get manifest <RELEASE_NAME> -n <NAMESPACE> > current-manifest.yaml
kubectl get all -n <NAMESPACE> -o yaml > all-resources.yaml
# Compare and identify orphaned resources

# Adopt orphaned resources (add labels/annotations)
kubectl label <RESOURCE> app.kubernetes.io/managed-by=Helm -n <NAMESPACE>
kubectl annotate <RESOURCE> meta.helm.sh/release-name=<RELEASE_NAME> -n <NAMESPACE>
kubectl annotate <RESOURCE> meta.helm.sh/release-namespace=<NAMESPACE> -n <NAMESPACE>
```
