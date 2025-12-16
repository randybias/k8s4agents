# Helm Debugging and Troubleshooting

Comprehensive guide for diagnosing Helm chart issues, release failures, and upgrade problems.

## Table of Contents

- [Helm Basics](#helm-basics)
- [Chart Validation](#chart-validation)
  - [Complete Validation Workflow](#complete-validation-workflow)
  - [Pre-Installation Validation](#pre-installation-validation)
  - [Template Rendering](#template-rendering)
  - [Dry-Run Installation](#dry-run-installation)
  - [Common Validation Errors](#common-validation-errors)
  - [Empty Manifest Troubleshooting](#empty-manifest-troubleshooting)
  - [Validation Automation](#validation-automation)
- [Release Troubleshooting](#release-troubleshooting)
- [Upgrade and Rollback Issues](#upgrade-and-rollback-issues)
- [Stuck Releases](#stuck-releases)
- [Secret and State Management](#secret-and-state-management)
- [Hook Failures](#hook-failures)
  - [Helm Hooks Overview](#helm-hooks-overview)
  - [Hook Investigation](#hook-investigation)
  - [Hook Policies and Annotations](#hook-policies-and-annotations)
  - [Hook Troubleshooting](#hook-troubleshooting)
  - [Common Hook Failure Patterns](#common-hook-failure-patterns)
  - [Hook Best Practices](#hook-best-practices)
- [Values and Templating](#values-and-templating)
- [Helm Testing](#helm-testing)
  - [Helm Test Overview](#helm-test-overview)
  - [Running Helm Tests](#running-helm-tests)
  - [Creating Test Templates](#creating-test-templates)
  - [Test Debugging](#test-debugging)
  - [Test Best Practices](#test-best-practices)
  - [Pre-Deployment Validation Workflow](#pre-deployment-validation-workflow)
- [Dependency Management](#dependency-management)
- [Using helm_release_debug.sh Script](#using-helm_release_debugsh-script)
  - [Script Overview](#script-overview)
  - [Basic Usage](#basic-usage)
  - [Interpreting Script Output](#interpreting-script-output)
  - [Integration with Other Workflows](#integration-with-other-workflows)
- [Best Practices](#best-practices)
- [Troubleshooting Checklist](#troubleshooting-checklist)
- [Emergency Recovery](#emergency-recovery)

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

Chart validation is the first line of defense against deployment failures. A comprehensive validation workflow catches issues before they impact production.

### Complete Validation Workflow

**Three-Phase Validation**:
1. **Lint**: Static analysis of chart structure
2. **Template**: Render and validate YAML syntax
3. **Dry-Run**: Server-side validation with Kubernetes API

```bash
# Phase 1: Lint chart
helm lint <CHART_PATH>
helm lint <CHART_PATH> -f <VALUES_FILE>
helm lint <CHART_PATH> --strict  # Fail on warnings

# Phase 2: Template rendering and YAML validation
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE> | kubectl apply --dry-run=client -f -

# Phase 3: Dry-run with server-side validation
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> -f <VALUES_FILE> --dry-run --debug

# Phase 4: Check for deprecated APIs
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=server -f - 2>&1 | grep -i "deprecated\|removed"
```

### Pre-Installation Validation

**Basic Linting**:
```bash
# Lint chart structure and syntax
helm lint <CHART_PATH>

# Lint with values file
helm lint <CHART_PATH> -f <VALUES_FILE>

# Strict mode (fail on warnings)
helm lint <CHART_PATH> --strict

# Lint with multiple values files
helm lint <CHART_PATH> -f values.yaml -f values-prod.yaml
```

**Lint Output Interpretation**:
```bash
# [INFO] messages: Informational, safe to ignore
# [WARNING] messages: Should be addressed but not blocking
# [ERROR] messages: Must be fixed before deployment

# Common lint errors:
# - Chart.yaml missing required fields (name, version, apiVersion)
# - Invalid template syntax
# - Missing values in templates
# - Invalid YAML indentation
```

**Advanced Linting**:
```bash
# Check all charts in directory
for chart in charts/*; do
  echo "Linting $chart"
  helm lint "$chart"
done

# Lint with debug output
helm lint <CHART_PATH> --debug

# Validate Chart.yaml schema
cat <CHART_PATH>/Chart.yaml | yq eval '.'
```

### Template Rendering

**Basic Template Rendering**:
```bash
# Render templates without installing
helm template <RELEASE_NAME> <CHART_PATH>

# Render with values file
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE>

# Render with inline values
helm template <RELEASE_NAME> <CHART_PATH> --set key=value

# Render with multiple values files (later files override earlier)
helm template <RELEASE_NAME> <CHART_PATH> -f base-values.yaml -f prod-values.yaml

# Output to file for inspection
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE> > rendered-manifest.yaml
```

**Selective Template Rendering**:
```bash
# Check specific template
helm template <RELEASE_NAME> <CHART_PATH> -s templates/deployment.yaml

# Render only templates matching pattern
helm template <RELEASE_NAME> <CHART_PATH> -s templates/hooks/*.yaml

# Show only specific resource types
helm template <RELEASE_NAME> <CHART_PATH> | grep -A 20 "kind: Deployment"
```

**Template Debugging**:
```bash
# Debug template rendering with verbose output
helm template <RELEASE_NAME> <CHART_PATH> --debug

# Show computed values
helm template <RELEASE_NAME> <CHART_PATH> --debug 2>&1 | grep "COMPUTED VALUES"

# Check if template produces empty manifests
helm template <RELEASE_NAME> <CHART_PATH> | grep -v "^---$" | grep -v "^#" | wc -l
# If count is 0 or very low, templates may be conditional and skipped
```

**Handling Conditional Templates**:
```bash
# Some templates may not render if conditions aren't met
# Example: ingress only renders if ingress.enabled=true

# Check what conditions exist
grep -r "if .Values" <CHART_PATH>/templates/

# Render with conditions enabled
helm template <RELEASE_NAME> <CHART_PATH> --set ingress.enabled=true

# Render all possible resources
helm template <RELEASE_NAME> <CHART_PATH> \
  --set ingress.enabled=true \
  --set autoscaling.enabled=true \
  --set serviceMonitor.enabled=true
```

**Empty Manifest Troubleshooting**:
```bash
# Problem: helm template produces empty or minimal output
# Common causes:
# 1. All templates are conditional and conditions not met
# 2. Values causing templates to be skipped
# 3. Template logic errors returning nothing

# Diagnosis:
# Check template conditions
grep -r "if\|range\|with" <CHART_PATH>/templates/

# Render with debug to see why templates skipped
helm template <RELEASE_NAME> <CHART_PATH> --debug 2>&1 | less

# Test with minimal values
helm template <RELEASE_NAME> <CHART_PATH> --set enabled=true

# Verify values are being read
helm template <RELEASE_NAME> <CHART_PATH> --debug 2>&1 | grep -A 50 "USER-SUPPLIED VALUES"
```

### Dry-Run Installation

**Client-Side Dry-Run**:
```bash
# Render and validate YAML syntax only
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run --debug

# Equivalent to template + client-side validation
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=client -f -
```

**Server-Side Dry-Run**:
```bash
# Validate against Kubernetes API (checks RBAC, quotas, API compatibility)
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run=server --debug

# Dry-run upgrade
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run=server --debug

# Dry-run with values
helm upgrade --install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> \
  -f <VALUES_FILE> --dry-run=server --debug
```

**Dry-Run vs. Template Differences**:
```bash
# helm template: Client-side only, no API server interaction
# - Faster
# - Doesn't check API versions, quotas, RBAC
# - Doesn't require cluster access

# helm install --dry-run: Server-side validation
# - Slower (API calls)
# - Validates API versions, quotas, RBAC
# - Requires cluster access
# - Catches more potential issues

# Best practice: Use both
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=client -f -
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run=server --debug
```

**Dry-Run Output Analysis**:
```bash
# Save dry-run output for review
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run --debug > dry-run.yaml 2>&1

# Extract only manifests (remove debug output)
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run 2>/dev/null > manifests.yaml

# Validate extracted manifests
kubectl apply --dry-run=server -f manifests.yaml

# Check resource counts
helm template <RELEASE_NAME> <CHART_PATH> | grep "^kind:" | sort | uniq -c
```

### Common Validation Errors

**Invalid YAML Syntax**:
```bash
# Lint will catch syntax errors
helm lint <CHART_PATH>

# Validate rendered YAML
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=client -f -

# Use yamllint for detailed validation
helm template <RELEASE_NAME> <CHART_PATH> | yamllint -

# Common issues:
# - Incorrect indentation
# - Missing quotes around special characters
# - Trailing spaces
# - Tab characters instead of spaces
```

**Missing Required Values**:
```bash
# Check Chart.yaml for required values
cat <CHART_PATH>/Chart.yaml

# Check values.yaml for defaults
cat <CHART_PATH>/values.yaml

# Validate with your values
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE> --validate

# Find undefined variables in templates
helm template <RELEASE_NAME> <CHART_PATH> --debug 2>&1 | grep "undefined"

# Common errors:
# - nil pointer evaluating: Value not defined in values.yaml
# - can't evaluate field: Typo in template variable name
```

**Deprecated Kubernetes APIs**:
```bash
# Check for API version issues (server-side)
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=server -f -

# Check for deprecated APIs
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=server -f - 2>&1 | grep -i "deprecated"

# Use pluto to scan for deprecated APIs
helm template <RELEASE_NAME> <CHART_PATH> | pluto detect -

# Common deprecated APIs (Kubernetes 1.25+):
# - PodSecurityPolicy (removed in 1.25)
# - Ingress: networking.k8s.io/v1beta1 -> networking.k8s.io/v1
# - CronJob: batch/v1beta1 -> batch/v1

# Use kubectl convert for API migrations (if available)
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl convert -f -
```

**Resource Name Conflicts**:
```bash
# Check if resources already exist
helm template <RELEASE_NAME> <CHART_PATH> | kubectl get -f - 2>&1

# Find name conflicts
helm template <RELEASE_NAME> <CHART_PATH> | grep "name:" | sort

# Validate unique names within chart
helm template <RELEASE_NAME> <CHART_PATH> | \
  yq eval '.metadata.name' - | sort | uniq -d
```

**RBAC and Quota Validation**:
```bash
# Test RBAC permissions
helm template <RELEASE_NAME> <CHART_PATH> | \
  kubectl auth reconcile --dry-run=server -f -

# Check against resource quotas
helm template <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> | \
  kubectl apply --dry-run=server -f -

# Validate service account exists
kubectl get sa -n <NAMESPACE> <SERVICE_ACCOUNT>
```

### Validation Automation

**Pre-Commit Validation Script**:
```bash
#!/usr/bin/env bash
# validate-chart.sh
set -euo pipefail

CHART_PATH="$1"
VALUES_FILE="${2:-values.yaml}"

echo "=== Linting Chart ==="
helm lint "$CHART_PATH" -f "$VALUES_FILE" --strict

echo "=== Validating Templates ==="
helm template test "$CHART_PATH" -f "$VALUES_FILE" | kubectl apply --dry-run=client -f -

echo "=== Checking for Deprecated APIs ==="
if helm template test "$CHART_PATH" | kubectl apply --dry-run=server -f - 2>&1 | grep -i "deprecated"; then
  echo "WARNING: Deprecated APIs found"
fi

echo "=== Validation Complete ==="
```

**CI/CD Integration**:
```yaml
# GitHub Actions example
- name: Validate Helm Charts
  run: |
    for chart in charts/*; do
      helm lint "$chart" --strict
      helm template test "$chart" | kubectl apply --dry-run=server -f -
    done
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

### Helm Hooks Overview

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

**Hook Execution Flow**:
1. User initiates Helm operation (install/upgrade)
2. Helm renders templates and identifies hook resources
3. Pre-hooks execute (must succeed unless policy allows failure)
4. Main resources are applied
5. Post-hooks execute
6. Release marked as deployed/failed based on hook outcomes

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

# List all hook resources for a release
kubectl get all -n <NAMESPACE> -l "app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=<RELEASE_NAME>"

# Check hook weight (execution order)
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | grep -A 2 "helm.sh/hook-weight"
```

### Hook Policies and Annotations

**Delete Policies**:
```yaml
annotations:
  # When to delete hook resources
  "helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
  # Options:
  # - before-hook-creation: Delete previous hook before new one
  # - hook-succeeded: Delete after successful execution
  # - hook-failed: Delete after failed execution
```

**Hook Weight** (execution order):
```yaml
annotations:
  "helm.sh/hook": "pre-upgrade"
  "helm.sh/hook-weight": "-5"  # Lower weight = earlier execution
  # Hooks execute in ascending order: -10, -5, 0, 1, 10
```

**Hook Failure Policy**:
```yaml
# Default behavior: Hook failure = release failure
# Use Jobs with restartPolicy: Never for hooks
# Or Jobs with backoffLimit for automatic retries
spec:
  backoffLimit: 3  # Retry up to 3 times
  activeDeadlineSeconds: 600  # Timeout after 10 minutes
```

### Hook Troubleshooting

**Failed Pre-Install/Pre-Upgrade Hook**:
```bash
# Check what failed
helm status <RELEASE_NAME> -n <NAMESPACE>
helm history <RELEASE_NAME> -n <NAMESPACE>

# Get hook pod logs
kubectl logs -n <NAMESPACE> -l "helm.sh/hook=pre-upgrade"

# Check if hook job completed
kubectl get job -n <NAMESPACE> -l "helm.sh/hook=pre-upgrade"

# Manual hook cleanup (if hook failed and blocked release)
kubectl delete job -n <NAMESPACE> -l "helm.sh/hook=pre-upgrade"

# Retry upgrade after fixing hook
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE>
```

**Failed Post-Install/Post-Upgrade Hook**:
```bash
# Post-hooks run after main resources are deployed
# Release may show as "deployed" but post-hook failed

# Check hook status
kubectl get jobs,pods -n <NAMESPACE> -l "helm.sh/hook=post-upgrade"

# View hook logs
kubectl logs -n <NAMESPACE> -l "helm.sh/hook=post-upgrade"

# If post-hook is non-critical, manually clean up
kubectl delete job -n <NAMESPACE> <POST_HOOK_JOB>

# If post-hook is critical, fix and re-run
# Option 1: Run hook manually
kubectl apply -f <HOOK_TEMPLATE_FILE>

# Option 2: Trigger another upgrade
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --reuse-values
```

**Stuck Hook (Running Forever)**:
```bash
# Identify stuck hook
kubectl get jobs -n <NAMESPACE> -l "app.kubernetes.io/managed-by=Helm"

# Check hook pod status
kubectl describe pod <HOOK_POD> -n <NAMESPACE>

# Check hook timeout settings
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | grep -A 10 "activeDeadlineSeconds"

# Manually terminate stuck hook
kubectl delete job <HOOK_JOB> -n <NAMESPACE>

# If release is stuck, consider rollback
helm rollback <RELEASE_NAME> -n <NAMESPACE>
```

**Hook Delete Policy Issues**:
```bash
# List orphaned hooks (should have been deleted)
kubectl get jobs,pods -n <NAMESPACE> -l "helm.sh/hook"

# Check delete policy
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | grep -B 5 -A 2 "hook-delete-policy"

# Manual cleanup of old hooks
kubectl delete job -n <NAMESPACE> <OLD_HOOK_JOB>
kubectl delete pod -n <NAMESPACE> <OLD_HOOK_POD>

# Prevent future accumulation
# Add to hook template:
# annotations:
#   "helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
```

**Emergency: Disable Hooks**:
```bash
# Skip all hooks during operation (use with caution)
helm upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --no-hooks

# This bypasses pre/post hooks entirely
# Useful for emergency fixes when hooks are broken
```

**Testing Hooks Separately**:
```bash
# Render specific hook template
helm template <RELEASE_NAME> <CHART_PATH> -s templates/<HOOK_TEMPLATE>

# Test hook in isolation
helm template <RELEASE_NAME> <CHART_PATH> -s templates/hooks/pre-upgrade-job.yaml | kubectl apply -f -

# Watch hook execution
kubectl logs -f <HOOK_POD> -n <NAMESPACE>

# Clean up test hook
kubectl delete -f <HOOK_TEMPLATE>
```

### Common Hook Failure Patterns

**Pattern 1: Database Migration Hook Fails**
```yaml
# Problem: DB migration hook times out or fails
# Symptoms: Release stuck in pending-upgrade, pod shows CrashLoopBackOff

# Solution:
# 1. Increase timeout
spec:
  activeDeadlineSeconds: 1800  # 30 minutes

# 2. Add retry logic
spec:
  backoffLimit: 3

# 3. Verify database connectivity in hook
# 4. Check migration scripts for errors
```

**Pattern 2: Hook Creates Resources Conflicting with Main Release**
```yaml
# Problem: Hook creates ConfigMap that main release also tries to create
# Symptoms: Release fails with "already exists" error

# Solution: Use hook delete policy
annotations:
  "helm.sh/hook": "pre-upgrade"
  "helm.sh/hook-delete-policy": "before-hook-creation"
  # Or make resources idempotent
```

**Pattern 3: Hook Depends on Main Release Resources**
```yaml
# Problem: Post-install hook tries to access service that isn't ready yet
# Symptoms: Hook fails immediately, service endpoint not found

# Solution: Add readiness checks in hook
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-service
        image: busybox
        command:
        - sh
        - -c
        - |
          until nslookup myservice.namespace.svc.cluster.local; do
            echo waiting for service
            sleep 2
          done
```

**Pattern 4: Hooks Not Executing in Expected Order**
```yaml
# Problem: Hooks run in wrong sequence
# Symptoms: Dependencies fail because prerequisite hook hasn't run

# Solution: Use hook weights
annotations:
  "helm.sh/hook": "pre-upgrade"
  "helm.sh/hook-weight": "-5"  # Run first

# Another hook:
annotations:
  "helm.sh/hook": "pre-upgrade"
  "helm.sh/hook-weight": "0"   # Run second
```

### Hook Best Practices

1. **Always set deletion policies**:
   ```yaml
   "helm.sh/hook-delete-policy": "before-hook-creation,hook-succeeded"
   ```

2. **Set reasonable timeouts**:
   ```yaml
   spec:
     activeDeadlineSeconds: 600  # 10 minutes
   ```

3. **Use Jobs, not Pods**:
   ```yaml
   # Jobs provide better lifecycle management
   kind: Job
   spec:
     backoffLimit: 2
     template:
       spec:
         restartPolicy: Never
   ```

4. **Implement retries**:
   ```yaml
   spec:
     backoffLimit: 3  # Retry failed hook up to 3 times
   ```

5. **Log verbosely**:
   ```bash
   # Make hooks easy to debug with clear logging
   echo "Starting database migration..."
   echo "Migration completed successfully"
   ```

6. **Make hooks idempotent**: Hooks should be safe to run multiple times

7. **Test hooks in isolation**: Always test hooks separately before deploying

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

## Helm Testing

### Helm Test Overview

Helm tests are Kubernetes pods with the `helm.sh/hook: test` annotation that run validation checks after deployment. Tests verify that a release is functioning correctly.

**Test Hook Lifecycle**:
1. Release is deployed
2. User runs `helm test <RELEASE_NAME>`
3. Helm creates test pods
4. Tests execute and report success/failure
5. Test pods remain for log inspection (unless cleaned up)

**Common Test Scenarios**:
- Service connectivity checks
- API endpoint validation
- Database connection tests
- Configuration verification
- Integration tests

### Running Helm Tests

**Basic Test Execution**:
```bash
# Run all tests for a release
helm test <RELEASE_NAME> -n <NAMESPACE>

# Run tests with streaming logs
helm test <RELEASE_NAME> -n <NAMESPACE> --logs

# Run tests with timeout (default 5m)
helm test <RELEASE_NAME> -n <NAMESPACE> --timeout 10m

# Run specific test by name
helm test <RELEASE_NAME> -n <NAMESPACE> --filter name=<TEST_NAME>
```

**Test Output and Status**:
```bash
# Check test execution results
# Success: All test pods exit with code 0
# Failure: Any test pod exits with non-zero code

# List test pods
kubectl get pods -n <NAMESPACE> -l "helm.sh/hook=test"

# Check test pod logs
kubectl logs <TEST_POD_NAME> -n <NAMESPACE>

# Get test pod exit code
kubectl get pod <TEST_POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
```

**Test Cleanup**:
```bash
# Test pods are NOT automatically deleted by default
# They remain for inspection

# Manually clean up test pods
kubectl delete pods -n <NAMESPACE> -l "helm.sh/hook=test"

# Or use hook-delete-policy in test template
# See "Creating Test Templates" below
```

### Creating Test Templates

**Basic Test Template Structure**:
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-connection"
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
spec:
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "mychart.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

**Test with Multiple Checks**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-suite"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  containers:
  - name: test-runner
    image: curlimages/curl:latest
    command:
    - sh
    - -c
    - |
      set -e
      echo "Testing service connectivity..."
      curl -f http://{{ include "mychart.fullname" . }}:{{ .Values.service.port }}/health

      echo "Testing API endpoint..."
      curl -f http://{{ include "mychart.fullname" . }}:{{ .Values.service.port }}/api/v1/status

      echo "All tests passed!"
  restartPolicy: Never
```

**Database Connection Test**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-db"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-weight": "1"  # Run after basic tests
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  containers:
  - name: postgres-test
    image: postgres:14
    env:
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .Values.database.secretName }}
          key: password
    command:
    - sh
    - -c
    - |
      psql -h {{ .Values.database.host }} \
           -U {{ .Values.database.user }} \
           -d {{ .Values.database.name }} \
           -c "SELECT 1"
  restartPolicy: Never
```

**Advanced Test with Init Container**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-integration"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  initContainers:
  - name: wait-for-service
    image: busybox
    command:
    - sh
    - -c
    - |
      until nslookup {{ include "mychart.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local; do
        echo "Waiting for service..."
        sleep 2
      done
  containers:
  - name: integration-test
    image: curlimages/curl:latest
    command:
    - sh
    - -c
    - |
      set -e
      # Wait for service to be ready
      sleep 5

      # Run integration tests
      curl -f http://{{ include "mychart.fullname" . }}:{{ .Values.service.port }}/api/test

      echo "Integration tests passed"
  restartPolicy: Never
```

### Test Debugging

**Failed Test Investigation**:
```bash
# Run test and capture output
helm test <RELEASE_NAME> -n <NAMESPACE> --logs 2>&1 | tee test-output.log

# Check test pod status
kubectl get pod -n <NAMESPACE> -l "helm.sh/hook=test"

# Get detailed test pod info
kubectl describe pod <TEST_POD> -n <NAMESPACE>

# View test logs
kubectl logs <TEST_POD> -n <NAMESPACE>

# Check previous logs if pod restarted
kubectl logs <TEST_POD> -n <NAMESPACE> --previous

# Check test pod events
kubectl get events -n <NAMESPACE> --field-selector involvedObject.name=<TEST_POD>
```

**Common Test Failures**:

**Test Timeout**:
```bash
# Problem: Test pod running but not completing
# Symptoms: "context deadline exceeded" error

# Diagnosis:
kubectl logs <TEST_POD> -n <NAMESPACE>  # Check what it's waiting for

# Solutions:
# 1. Increase timeout
helm test <RELEASE_NAME> -n <NAMESPACE> --timeout 15m

# 2. Add timeout to test script
command:
- sh
- -c
- |
  timeout 300 curl -f http://service:8080/health
```

**Service Not Ready**:
```bash
# Problem: Test runs before service is ready
# Symptoms: Connection refused, DNS lookup failed

# Solution: Add readiness wait in test
initContainers:
- name: wait-for-service
  image: busybox
  command:
  - sh
  - -c
  - |
    until nslookup myservice.namespace.svc.cluster.local; do
      echo "Waiting..."
      sleep 2
    done
```

**Permission Issues**:
```bash
# Problem: Test pod lacks RBAC permissions
# Symptoms: Forbidden, Unauthorized errors

# Solution: Add ServiceAccount to test
spec:
  serviceAccountName: {{ include "mychart.fullname" . }}-test
  # And create corresponding RBAC in templates
```

**Test Pod ImagePullBackOff**:
```bash
# Problem: Test image cannot be pulled
# Symptoms: ErrImagePull, ImagePullBackOff

# Diagnosis:
kubectl describe pod <TEST_POD> -n <NAMESPACE>

# Solutions:
# 1. Use public image or add imagePullSecrets
# 2. Verify image exists and tag is correct
# 3. Check image pull secrets in test pod spec
```

### Test Best Practices

1. **Use hook-delete-policy**:
   ```yaml
   annotations:
     "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
     # Or: hook-succeeded (keep failed for debugging)
   ```

2. **Make tests idempotent**: Tests should be safe to run multiple times

3. **Set appropriate timeouts**:
   ```yaml
   spec:
     activeDeadlineSeconds: 300  # 5 minutes
   ```

4. **Use specific test images**: Don't use `latest` tag
   ```yaml
   image: curlimages/curl:7.85.0  # Specific version
   ```

5. **Add verbose logging**:
   ```bash
   echo "Testing endpoint X..."
   curl -v -f http://service/endpoint
   echo "Test passed"
   ```

6. **Test multiple scenarios**:
   - Basic connectivity
   - API endpoints
   - Authentication
   - Database connections
   - Integration points

7. **Use test weights for ordering**:
   ```yaml
   annotations:
     "helm.sh/hook": test
     "helm.sh/hook-weight": "1"  # Run after weight 0 tests
   ```

8. **Include cleanup in test**:
   ```bash
   # Clean up test data
   trap "curl -X DELETE http://service/test-data" EXIT
   ```

### Automated Test Validation

**Test in CI/CD Pipeline**:
```bash
#!/usr/bin/env bash
# run-helm-tests.sh
set -euo pipefail

RELEASE="$1"
NAMESPACE="$2"

echo "Running Helm tests for $RELEASE..."

if helm test "$RELEASE" -n "$NAMESPACE" --logs --timeout 10m; then
  echo "All tests passed!"
  exit 0
else
  echo "Tests failed!"
  echo "Collecting test pod logs..."
  kubectl logs -n "$NAMESPACE" -l "helm.sh/hook=test"
  exit 1
fi
```

**GitHub Actions Integration**:
```yaml
- name: Deploy and Test
  run: |
    helm upgrade --install myapp ./chart -n test --wait
    helm test myapp -n test --logs
    kubectl delete pods -n test -l "helm.sh/hook=test"
```

### Pre-Deployment Validation Workflow

Complete validation before production deployment:

```bash
# 1. Lint chart
helm lint <CHART_PATH>

# 2. Template and validate YAML
helm template <RELEASE_NAME> <CHART_PATH> -f <VALUES_FILE> | kubectl apply --dry-run=server -f -

# 3. Dry-run install
helm install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> -f <VALUES_FILE> --dry-run --debug

# 4. Check for deprecated APIs
helm template <RELEASE_NAME> <CHART_PATH> | kubectl apply --dry-run=server -f - 2>&1 | grep -i deprecated

# 5. Deploy to test environment
helm upgrade --install <RELEASE_NAME> <CHART_PATH> -n test -f <VALUES_FILE> --wait

# 6. Run Helm tests
helm test <RELEASE_NAME> -n test --logs

# 7. Run additional validation
kubectl get pods -n test
kubectl get svc -n test

# 8. Clean up tests
kubectl delete pods -n test -l "helm.sh/hook=test"
```

### Test vs. Hook Comparison

**helm test hook** vs. **post-install hook**:

| Aspect | Test Hook | Post-Install Hook |
|--------|-----------|-------------------|
| Trigger | Manual (`helm test`) | Automatic (during install) |
| Failure impact | Informational | Blocks release |
| Use case | Validation, smoke tests | Setup, migrations |
| Cleanup | Manual or policy | Policy-based |
| Execution | On-demand | Once per install |

**When to use each**:
- **Test hooks**: Optional validation, smoke tests, integration tests
- **Post-install hooks**: Required setup steps, database migrations, configuration

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

## Using helm_release_debug.sh Script

The k8s-troubleshooter skill includes an automated Helm debugging script that provides comprehensive release diagnostics in one command.

### Script Overview

**Location**: `~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh`

**Purpose**: Automated first-pass investigation for Helm release issues

**What it does**:
1. Checks release status and history
2. Shows current release values
3. Validates deployed resources exist
4. Displays recent namespace events
5. Lists Helm secrets
6. Shows pods managed by the release

### Basic Usage

```bash
# Standard invocation
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE>

# Example
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production

# Default namespace (if not specified, uses 'default')
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp
```

### Script Output Sections

**1. Release Status**:
- Current status (deployed, failed, pending-upgrade)
- Last deployed time
- Release notes
- Deployed chart version

**2. Release History**:
- All revisions with timestamps
- Status of each revision (deployed, superseded, failed)
- Chart versions across revisions
- Useful for identifying when failures started

**3. Current Release Values**:
- User-supplied values (not defaults)
- Values from values files and --set flags
- Compare across revisions to identify config changes

**4. Deployed Resources**:
- Lists all resources created by the release
- Shows current status (running, failed, etc.)
- Identifies missing resources (deleted outside Helm)

**5. Recent Events**:
- Last 20 namespace events
- Warnings and errors related to release
- Helps correlate release actions with cluster events

**6. Helm Secrets**:
- Lists release secret revisions
- Identifies orphaned secrets
- Useful for troubleshooting stuck releases

**7. Pods Status**:
- Shows pods managed by the release
- Includes standard Helm labels
- Quick health check of release workloads

### When to Use the Script

**Use this script FIRST when**:
- Release status shows failed or pending
- Upgrade appears stuck
- Resources are missing or unhealthy
- Need quick overview of release state

**Follow up with manual commands when**:
- Script identifies specific issues to investigate
- Need deeper dive into specific resources
- Debugging template or values problems
- Investigating hook failures

### Example Workflow

```bash
# 1. Run automated script first
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production

# Script output shows:
# - Release status: failed
# - History: Last revision failed during pre-upgrade hook
# - Events: Hook pod failed with exit code 1

# 2. Based on script output, investigate hook
kubectl get jobs -n production -l "helm.sh/hook=pre-upgrade"
kubectl logs -n production <HOOK_JOB_POD>

# 3. Fix hook issue and retry upgrade
helm upgrade myapp ./chart -n production --reuse-values

# 4. Verify with script again
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production
```

### Interpreting Script Output

**Release Status Indicators**:
```bash
# STATUS: deployed - Healthy, no action needed
# STATUS: failed - Check history and events sections
# STATUS: pending-upgrade - May be stuck, check for hooks
# STATUS: pending-install - Installation in progress or stuck
```

**History Analysis**:
```bash
# Look for pattern of failures
# REVISION  STATUS      CHART        DESCRIPTION
# 1         superseded  myapp-1.0.0  Install complete
# 2         superseded  myapp-1.1.0  Upgrade complete
# 3         failed      myapp-1.2.0  Upgrade "myapp" failed: pre-upgrade hook failed

# This indicates: version 1.2.0 introduced a problem with pre-upgrade hook
```

**Resource Status**:
```bash
# Resources listed but showing errors
# NAME              READY   STATUS             RESTARTS
# myapp-abc123      0/1     CrashLoopBackOff   5

# Follow up: kubectl logs myapp-abc123 -n production
```

**Missing Resources**:
```bash
# Output: "Some resources may not exist"
# Means: Resources in manifest were deleted outside Helm
# Action: Check if manual cleanup occurred
```

### Integration with Other Workflows

**Combine with incident triage**:
```bash
# 1. Run incident triage for overview
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --skip-dump

# 2. If Helm release issues detected, use Helm debug script
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE>

# 3. Follow up with specific diagnostics based on findings
```

**Part of troubleshooting workflow**:
```bash
# Quick status check
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp prod

# If pods failing, use pod diagnostics
~/.claude/skills/k8s-troubleshooter/scripts/pod_diagnostics.sh <POD_NAME> prod

# If network issues, use network debug
~/.claude/skills/k8s-troubleshooter/scripts/network_debug.sh prod
```

### Script Limitations

**What the script DOES NOT do**:
- Template validation (use `helm template` or `helm lint`)
- Chart structure validation (use `helm lint`)
- Deep dive into specific resources (use kubectl commands)
- Fix issues automatically (read-only diagnostics)

**When you need manual commands**:
- Validating chart before deployment
- Testing template rendering with different values
- Debugging complex hook logic
- Performing recovery operations (rollback, upgrade, delete)

### Extending the Script

The script is designed to be readable and extensible. Key sections to customize:

```bash
# Add custom checks for your environment
echo ""
echo "=== Custom Organization Checks ==="
# Your custom validation here

# Filter pods by additional labels
kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance="$RELEASE_NAME",custom-label=value
```

### Common Patterns and Solutions

**Pattern: Release shows failed, hook issues in events**:
```bash
# Script shows: pre-upgrade hook pod failed
# Solution pathway:
kubectl get jobs -n <NAMESPACE> -l "helm.sh/hook=pre-upgrade"
kubectl logs <HOOK_POD> -n <NAMESPACE>
# Fix hook, then retry upgrade
```

**Pattern: Release deployed but pods crashing**:
```bash
# Script shows: STATUS deployed, but pods CrashLoopBackOff
# Solution pathway:
kubectl logs <POD_NAME> -n <NAMESPACE>
kubectl describe pod <POD_NAME> -n <NAMESPACE>
# Fix app issue, then upgrade with new image/config
```

**Pattern: Resources missing from manifest**:
```bash
# Script shows: "Some resources may not exist"
# Solution pathway:
helm get manifest <RELEASE_NAME> -n <NAMESPACE> > expected.yaml
kubectl get all -n <NAMESPACE> -o yaml > actual.yaml
# Compare to find discrepancies
# Consider: helm upgrade --force if resources were deleted
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
11. **Use automation scripts first** - Run helm_release_debug.sh before manual commands
12. **Follow validation workflow** - Lint → Template → Dry-run → Deploy → Test

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
