# Helm Release Debug Test Plan

## Overview

### Purpose
This test plan provides a comprehensive set of test scenarios to validate the `helm_release_debug.sh` script and related Helm debugging procedures. Each scenario systematically induces specific failure conditions that the script is designed to detect and diagnose.

### Scope
- Hook failures (pre/post install/upgrade, timeouts, stuck hooks)
- Release state issues (failed, pending, empty manifests)
- Chart validation issues (lint, template, API deprecation)
- Dry-run failures (client/server-side, RBAC, quotas)
- Test failures (pod failures, timeouts, ImagePullBackOff)
- Resource conflicts and configuration errors

### Test Environment
- **Kubernetes cluster**: Any cluster with Helm 3.x installed
- **Namespace**: Use dedicated test namespaces (helm-test-*)
- **Cleanup**: Each test includes cleanup steps to restore cluster state

## Prerequisites

### Required Tools
```bash
# Verify tools are installed
helm version         # Helm 3.x required
kubectl version      # Kubernetes 1.20+ recommended
```

### Cluster Setup
```bash
# Create test namespaces
kubectl create namespace helm-test-hooks
kubectl create namespace helm-test-states
kubectl create namespace helm-test-validation
kubectl create namespace helm-test-dryrun
kubectl create namespace helm-test-tests

# Verify access
kubectl auth can-i create deployments --namespace=helm-test-hooks
```

### Test Chart Location
All test charts are located in `/Users/rbias/code/k8s4agents/scratch/test-charts/`

## Test Structure

Tests are organized by failure category:
1. **Hook Failures** (HF-001 to HF-007)
2. **Release State Issues** (RS-001 to RS-005)
3. **Chart Validation Issues** (CV-001 to CV-006)
4. **Dry-Run Issues** (DR-001 to DR-005)
5. **Test Failures** (TF-001 to TF-004)
6. **Other Scenarios** (OS-001 to OS-003)

Each test follows this structure:
- **Scenario ID and Name**
- **Description**: What failure condition is being tested
- **Prerequisites**: Any specific setup needed
- **Test Steps**: How to induce the failure
- **Expected Behavior**: What the debug script should detect
- **Validation**: How to confirm detection
- **Cleanup**: Steps to restore cluster state

---

## Hook Failures

### HF-001: Pre-Install Hook Failure

**Description**: Test detection of a failing pre-install hook that prevents chart installation.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy chart with failing pre-install hook
cd /Users/rbias/code/k8s4agents/scratch/test-charts
helm install test-pre-install-fail ./hook-pre-install-fail -n helm-test-hooks

# 2. Observe installation failure
helm list -n helm-test-hooks --all

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-pre-install-fail helm-test-hooks
```

**Expected Behavior**:
- Release status shows "pending-install" or "failed"
- Hook section shows pre-install job with failed status
- Hook pod logs show exit code 1
- Events show hook failure messages
- Script identifies hook as the blocker

**Validation**:
```bash
# Verify hook job failed
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=pre-install"

# Verify hook pod failed
kubectl get pods -n helm-test-hooks -l "helm.sh/hook=pre-install"

# Check pod logs show error
kubectl logs -n helm-test-hooks -l "helm.sh/hook=pre-install"
```

**Cleanup**:
```bash
helm uninstall test-pre-install-fail -n helm-test-hooks
kubectl delete jobs -n helm-test-hooks -l "helm.sh/hook=pre-install"
kubectl delete pods -n helm-test-hooks --all
```

---

### HF-002: Post-Install Hook Failure

**Description**: Test detection of a post-install hook that fails after main resources are deployed.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy chart with failing post-install hook
helm install test-post-install-fail ./hook-post-install-fail -n helm-test-hooks

# 2. Wait for deployment to complete but post-hook to fail
sleep 10

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-post-install-fail helm-test-hooks
```

**Expected Behavior**:
- Release status may show "deployed" (main resources succeeded)
- Hook section shows post-install job failed
- Main application pods are running
- Hook pod logs show error
- Script identifies post-hook failure

**Validation**:
```bash
# Main app should be running
kubectl get pods -n helm-test-hooks -l "app=test-app"

# Post-hook should be failed
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=post-install"
kubectl logs -n helm-test-hooks -l "helm.sh/hook=post-install"
```

**Cleanup**:
```bash
helm uninstall test-post-install-fail -n helm-test-hooks
kubectl delete jobs,pods -n helm-test-hooks --all
```

---

### HF-003: Pre-Upgrade Hook Failure

**Description**: Test detection of a failing pre-upgrade hook that blocks chart upgrades.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy initial version successfully
helm install test-pre-upgrade ./hook-pre-upgrade-fail -n helm-test-hooks \
  --set failPreUpgrade=false

# 2. Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-hooks --timeout=60s

# 3. Attempt upgrade with failing pre-upgrade hook
helm upgrade test-pre-upgrade ./hook-pre-upgrade-fail -n helm-test-hooks \
  --set failPreUpgrade=true

# 4. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-pre-upgrade helm-test-hooks
```

**Expected Behavior**:
- Release status shows "pending-upgrade" or "failed"
- History shows revision 1 deployed, revision 2 failed
- Hook section shows pre-upgrade job failed
- Previous version still running
- Script identifies upgrade blocked by pre-upgrade hook

**Validation**:
```bash
# Check release history
helm history test-pre-upgrade -n helm-test-hooks

# Verify hook failure
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=pre-upgrade"
kubectl logs -n helm-test-hooks -l "helm.sh/hook=pre-upgrade"

# Verify old version still running
kubectl get pods -n helm-test-hooks -l app=test-app -o wide
```

**Cleanup**:
```bash
helm uninstall test-pre-upgrade -n helm-test-hooks
kubectl delete jobs,pods -n helm-test-hooks --all
```

---

### HF-004: Post-Upgrade Hook Failure

**Description**: Test detection of a post-upgrade hook that fails after upgrade completes.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy initial version
helm install test-post-upgrade ./hook-post-upgrade-fail -n helm-test-hooks \
  --set version=v1 --set failPostUpgrade=false

# 2. Upgrade with failing post-upgrade hook
helm upgrade test-post-upgrade ./hook-post-upgrade-fail -n helm-test-hooks \
  --set version=v2 --set failPostUpgrade=true

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-post-upgrade helm-test-hooks
```

**Expected Behavior**:
- Release may show "deployed" status
- New version is running
- Post-upgrade hook failed
- Hook logs show error
- Script identifies post-upgrade hook failure

**Validation**:
```bash
# Verify new version deployed
kubectl get pods -n helm-test-hooks -l app=test-app -o yaml | grep "version: v2"

# Verify post-hook failed
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=post-upgrade"
kubectl logs -n helm-test-hooks -l "helm.sh/hook=post-upgrade"
```

**Cleanup**:
```bash
helm uninstall test-post-upgrade -n helm-test-hooks
kubectl delete jobs,pods -n helm-test-hooks --all
```

---

### HF-005: Stuck/Hanging Hook

**Description**: Test detection of a hook that runs indefinitely without completing.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy chart with long-running hook (no timeout set)
helm install test-stuck-hook ./hook-stuck -n helm-test-hooks

# 2. Wait 60 seconds for hook to be obviously stuck
sleep 60

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-stuck-hook helm-test-hooks
```

**Expected Behavior**:
- Release status shows "pending-install"
- Hook job shows active/running
- Hook pod is running but never completes
- Events may show no errors (just running)
- Script identifies hook as running but not completing

**Validation**:
```bash
# Verify hook is running
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=pre-install"
kubectl get pods -n helm-test-hooks -l "helm.sh/hook=pre-install"

# Check pod status is Running
kubectl get pod -n helm-test-hooks -l "helm.sh/hook=pre-install" -o jsonpath='{.items[0].status.phase}'

# Logs should show infinite loop
kubectl logs -n helm-test-hooks -l "helm.sh/hook=pre-install"
```

**Cleanup**:
```bash
# Must force delete stuck resources
kubectl delete jobs -n helm-test-hooks --all --force --grace-period=0
helm uninstall test-stuck-hook -n helm-test-hooks
kubectl delete pods -n helm-test-hooks --all
```

---

### HF-006: Hook Timeout

**Description**: Test detection of a hook that times out due to activeDeadlineSeconds.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy chart with hook that will timeout
helm install test-hook-timeout ./hook-timeout -n helm-test-hooks

# 2. Wait for timeout to trigger (30 seconds based on chart)
sleep 40

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-hook-timeout helm-test-hooks
```

**Expected Behavior**:
- Release status shows "failed" or "pending-install"
- Hook job shows failed due to DeadlineExceeded
- Pod shows status "DeadlineExceeded"
- Events show "Job was active longer than specified deadline"
- Script identifies timeout as cause

**Validation**:
```bash
# Verify job shows timeout
kubectl describe job -n helm-test-hooks -l "helm.sh/hook=pre-install" | grep -i deadline

# Verify pod shows DeadlineExceeded
kubectl get pod -n helm-test-hooks -l "helm.sh/hook=pre-install" -o jsonpath='{.items[0].status.reason}'

# Check events
kubectl get events -n helm-test-hooks --sort-by='.lastTimestamp' | grep -i deadline
```

**Cleanup**:
```bash
helm uninstall test-hook-timeout -n helm-test-hooks
kubectl delete jobs,pods -n helm-test-hooks --all
```

---

### HF-007: Hook Delete Policy Issues

**Description**: Test detection of orphaned hooks that should have been deleted.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy chart with hook that has no delete policy
helm install test-hook-orphan ./hook-no-delete-policy -n helm-test-hooks

# 2. Install completes successfully
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-hooks --timeout=60s

# 3. Upgrade the release
helm upgrade test-hook-orphan ./hook-no-delete-policy -n helm-test-hooks --set version=v2

# 4. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-hook-orphan helm-test-hooks
```

**Expected Behavior**:
- Multiple hook jobs/pods remain after successful execution
- Jobs from both initial install and upgrade are present
- Script lists orphaned hooks
- Hooks are in "Completed" status but not deleted

**Validation**:
```bash
# Should see multiple completed hook jobs
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook"

# Should see multiple completed hook pods
kubectl get pods -n helm-test-hooks -l "helm.sh/hook"

# Jobs should be completed
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook" -o jsonpath='{.items[*].status.succeeded}'
```

**Cleanup**:
```bash
helm uninstall test-hook-orphan -n helm-test-hooks
kubectl delete jobs,pods -n helm-test-hooks --all
```

---

## Release State Issues

### RS-001: Failed Release

**Description**: Test detection and diagnosis of a release in failed state.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-states
```

**Test Steps**:
```bash
# 1. Deploy chart that will fail (invalid image)
helm install test-failed ./failed-release -n helm-test-states --wait=false

# 2. Wait for failure to manifest
sleep 30

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-failed helm-test-states
```

**Expected Behavior**:
- Release status shows "failed"
- History shows failed revision
- Pod shows ImagePullBackOff or similar error
- Events show image pull errors
- Script identifies failure cause and suggests rollback

**Validation**:
```bash
# Verify release failed
helm list -n helm-test-states --all | grep failed

# Check pod status
kubectl get pods -n helm-test-states

# Verify error in events
kubectl get events -n helm-test-states --sort-by='.lastTimestamp' | grep -i error
```

**Cleanup**:
```bash
helm uninstall test-failed -n helm-test-states
kubectl delete pods -n helm-test-states --all
```

---

### RS-002: Pending-Install Release

**Description**: Test detection of a release stuck in pending-install state.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-states
```

**Test Steps**:
```bash
# 1. Deploy chart with resource that won't become ready
helm install test-pending-install ./pending-install -n helm-test-states --wait=false

# 2. Wait for state to persist
sleep 30

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-pending-install helm-test-states
```

**Expected Behavior**:
- Release status shows "pending-install"
- Resources are created but not ready
- Script warns about pending state
- Suggests checking for stuck operations

**Validation**:
```bash
# Verify pending state
helm list -n helm-test-states --pending

# Check pod is pending or not ready
kubectl get pods -n helm-test-states
```

**Cleanup**:
```bash
helm uninstall test-pending-install -n helm-test-states
kubectl delete pods -n helm-test-states --all
```

---

### RS-003: Pending-Upgrade Release

**Description**: Test detection of a release stuck in pending-upgrade state.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-states
```

**Test Steps**:
```bash
# 1. Deploy initial version
helm install test-pending-upgrade ./pending-upgrade -n helm-test-states \
  --set version=v1

# 2. Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-states --timeout=60s

# 3. Start upgrade that will get stuck
helm upgrade test-pending-upgrade ./pending-upgrade -n helm-test-states \
  --set version=v2 --set failUpgrade=true --wait=false

# 4. Wait for stuck state
sleep 30

# 5. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-pending-upgrade helm-test-states
```

**Expected Behavior**:
- Release status shows "pending-upgrade"
- History shows revision 1 deployed, revision 2 pending
- Script warns about stuck upgrade
- Suggests rollback or investigation

**Validation**:
```bash
# Verify pending-upgrade state
helm list -n helm-test-states --pending

# Check history
helm history test-pending-upgrade -n helm-test-states | grep pending
```

**Cleanup**:
```bash
helm rollback test-pending-upgrade -n helm-test-states || true
helm uninstall test-pending-upgrade -n helm-test-states
kubectl delete pods -n helm-test-states --all
```

---

### RS-004: Empty Manifest

**Description**: Test detection of a release with an empty or minimal manifest.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-states
```

**Test Steps**:
```bash
# 1. Deploy chart with conditional templates all disabled
helm install test-empty-manifest ./empty-manifest -n helm-test-states \
  --set enabled=false

# 2. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-empty-manifest helm-test-states
```

**Expected Behavior**:
- Release status shows "deployed" but no resources
- Manifest is empty or only contains comments
- Script warns about empty manifest
- Suggests checking chart conditions

**Validation**:
```bash
# Verify manifest is empty
helm get manifest test-empty-manifest -n helm-test-states

# Should show no pods
kubectl get pods -n helm-test-states
```

**Cleanup**:
```bash
helm uninstall test-empty-manifest -n helm-test-states
```

---

### RS-005: Missing Resources (Deleted Outside Helm)

**Description**: Test detection when resources are deleted manually outside of Helm.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-states
```

**Test Steps**:
```bash
# 1. Deploy chart successfully
helm install test-missing-resources ./basic-app -n helm-test-states

# 2. Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-states --timeout=60s

# 3. Manually delete deployment (simulating out-of-band deletion)
kubectl delete deployment -n helm-test-states -l app=test-app

# 4. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-missing-resources helm-test-states
```

**Expected Behavior**:
- Release status shows "deployed" (Helm doesn't know about deletion)
- Manifest contains resources that don't exist
- Script reports "Some resources may not exist"
- Resource check shows NotFound errors

**Validation**:
```bash
# Helm thinks it's deployed
helm status test-missing-resources -n helm-test-states

# But resources don't exist
kubectl get deployment -n helm-test-states | grep test-app || echo "Not found"

# Get manifest shows resources that should exist
helm get manifest test-missing-resources -n helm-test-states | kubectl get -f - 2>&1 | grep -i "not found"
```

**Cleanup**:
```bash
helm uninstall test-missing-resources -n helm-test-states
```

---

## Chart Validation Issues

### CV-001: Lint Failures - Invalid Chart.yaml

**Description**: Test detection of invalid Chart.yaml structure.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
```

**Test Steps**:
```bash
# 1. Attempt to lint chart with invalid Chart.yaml
helm lint ./lint-fail-chart-yaml

# 2. Attempt to install (should fail)
helm install test-lint-fail ./lint-fail-chart-yaml -n helm-test-validation --dry-run

# 3. Run validation with debug script options (requires chart path)
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-lint-fail helm-test-validation \
  --chart ./lint-fail-chart-yaml --validate-chart
```

**Expected Behavior**:
- Lint fails with errors about Chart.yaml
- Missing required fields (name, version, apiVersion)
- Cannot proceed with installation
- Script validation shows lint failure

**Validation**:
```bash
# Verify lint fails
helm lint ./lint-fail-chart-yaml 2>&1 | grep -i error

# Check Chart.yaml content
cat ./lint-fail-chart-yaml/Chart.yaml
```

**Cleanup**:
```bash
# No cleanup needed - chart never deployed
```

---

### CV-002: Lint Failures - Syntax Errors

**Description**: Test detection of YAML syntax errors in templates.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
```

**Test Steps**:
```bash
# 1. Lint chart with syntax errors
helm lint ./lint-fail-syntax

# 2. Attempt template rendering
helm template test-syntax ./lint-fail-syntax
```

**Expected Behavior**:
- Lint reports YAML syntax errors
- Invalid indentation detected
- Template rendering fails
- Clear error messages pointing to problematic lines

**Validation**:
```bash
# Verify syntax error reported
helm lint ./lint-fail-syntax 2>&1 | grep -i "syntax\|indent\|yaml"

# Template should fail
helm template test-syntax ./lint-fail-syntax 2>&1 | grep -i error
```

**Cleanup**:
```bash
# No cleanup needed
```

---

### CV-003: Template Rendering Failures

**Description**: Test detection of template rendering errors.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
```

**Test Steps**:
```bash
# 1. Attempt to render templates with undefined variables
helm template test-template-fail ./template-fail

# 2. Attempt with validation
helm template test-template-fail ./template-fail --validate
```

**Expected Behavior**:
- Template rendering fails
- Error shows undefined variable or nil pointer
- Points to specific template file and line
- Validation catches the issue

**Validation**:
```bash
# Verify template error
helm template test-template-fail ./template-fail 2>&1 | grep -i "nil\|undefined\|error"

# Check templates for issues
grep -r "\.Values\." ./template-fail/templates/
```

**Cleanup**:
```bash
# No cleanup needed
```

---

### CV-004: Missing Required Values

**Description**: Test detection when required values are not provided.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
```

**Test Steps**:
```bash
# 1. Attempt to render without required values
helm template test-missing-values ./missing-required-values

# 2. Attempt installation
helm install test-missing-values ./missing-required-values -n helm-test-validation --dry-run
```

**Expected Behavior**:
- Template rendering fails
- Error indicates missing required value
- Shows which value is required
- Suggests checking values.yaml

**Validation**:
```bash
# Verify error about missing values
helm template test-missing-values ./missing-required-values 2>&1 | grep -i "required\|missing"

# Check what values are needed
cat ./missing-required-values/templates/deployment.yaml | grep required
```

**Cleanup**:
```bash
# No cleanup needed
```

---

### CV-005: Deprecated Kubernetes APIs

**Description**: Test detection of deprecated or removed Kubernetes APIs.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
kubectl config set-context --current --namespace=helm-test-validation
```

**Test Steps**:
```bash
# 1. Render chart with deprecated APIs
helm template test-deprecated ./deprecated-apis

# 2. Attempt server-side dry-run
helm install test-deprecated ./deprecated-apis -n helm-test-validation --dry-run=server
```

**Expected Behavior**:
- Template renders (client-side doesn't validate APIs)
- Server-side dry-run shows deprecation warnings
- Kubernetes API server rejects removed APIs
- Clear error message about API version

**Validation**:
```bash
# Check for deprecated API usage
helm template test-deprecated ./deprecated-apis | grep -i "apiVersion"

# Server-side should warn or fail
helm template test-deprecated ./deprecated-apis | kubectl apply --dry-run=server -f - 2>&1 | grep -i "deprecated\|no.*resource\|unsupported"
```

**Cleanup**:
```bash
# No cleanup needed
```

---

### CV-006: YAML Syntax Errors

**Description**: Test detection of invalid YAML syntax in values or templates.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
```

**Test Steps**:
```bash
# 1. Attempt to lint chart with YAML errors
helm lint ./yaml-syntax-error

# 2. Attempt template rendering
helm template test-yaml-error ./yaml-syntax-error
```

**Expected Behavior**:
- Lint fails immediately
- YAML parser error reported
- Points to file and line number
- Describes syntax issue (tabs, indentation, special characters)

**Validation**:
```bash
# Verify YAML syntax error
helm lint ./yaml-syntax-error 2>&1 | grep -i "yaml\|syntax\|parse"

# Check problematic file
cat ./yaml-syntax-error/templates/deployment.yaml
```

**Cleanup**:
```bash
# No cleanup needed
```

---

## Dry-Run Issues

### DR-001: Client-Side Dry-Run Failures

**Description**: Test detection of issues caught by client-side dry-run.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
```

**Test Steps**:
```bash
# 1. Attempt client-side dry-run with invalid YAML
helm install test-client-dryrun ./client-dryrun-fail -n helm-test-dryrun --dry-run

# 2. Run debug script with dry-run option
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-client-dryrun helm-test-dryrun \
  --chart ./client-dryrun-fail --run-dry-run
```

**Expected Behavior**:
- Client-side dry-run fails
- YAML validation error reported
- Does not contact Kubernetes API server
- Script shows client-side dry-run failure

**Validation**:
```bash
# Verify client-side error
helm install test-client-dryrun ./client-dryrun-fail -n helm-test-dryrun --dry-run 2>&1 | grep -i error
```

**Cleanup**:
```bash
# No cleanup needed
```

---

### DR-002: Server-Side Dry-Run Failures

**Description**: Test detection of issues caught only by server-side validation.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
kubectl config set-context --current --namespace=helm-test-dryrun
```

**Test Steps**:
```bash
# 1. Client-side dry-run succeeds
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run

# 2. Server-side dry-run fails
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run=server

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-server-dryrun helm-test-dryrun \
  --chart ./server-dryrun-fail --run-dry-run
```

**Expected Behavior**:
- Client-side dry-run passes
- Server-side dry-run fails
- API compatibility issue detected
- Server returns validation error

**Validation**:
```bash
# Client succeeds
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run 2>&1 | tail -5

# Server fails
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run=server 2>&1 | grep -i error
```

**Cleanup**:
```bash
# No cleanup needed
```

---

### DR-003: API Compatibility Issues

**Description**: Test detection of Kubernetes API version incompatibilities.

**Prerequisites**:
```bash
cd /Users/rbias/code/k8s4agents/scratch/test-charts
```

**Test Steps**:
```bash
# 1. Attempt to deploy chart with incompatible API version
helm install test-api-compat ./api-incompatible -n helm-test-dryrun --dry-run=server
```

**Expected Behavior**:
- Server-side validation fails
- API version not supported by cluster
- Error message shows expected vs. actual API version
- Suggests updating chart API versions

**Validation**:
```bash
# Check cluster API versions
kubectl api-versions | grep -i batch

# Verify chart uses unsupported version
helm template test-api-compat ./api-incompatible | grep apiVersion

# Server rejects
helm install test-api-compat ./api-incompatible -n helm-test-dryrun --dry-run=server 2>&1 | grep -i "no.*matches\|unsupported"
```

**Cleanup**:
```bash
# No cleanup needed
```

---

### DR-004: Resource Quota Violations

**Description**: Test detection of resource quota violations during dry-run.

**Prerequisites**:
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

**Test Steps**:
```bash
# 1. Attempt to deploy chart that exceeds quota
helm install test-quota ./quota-violation -n helm-test-dryrun --dry-run=server
```

**Expected Behavior**:
- Server-side dry-run fails
- Quota exceeded error
- Shows requested vs. available resources
- Suggests adjusting requests/limits

**Validation**:
```bash
# Verify quota exists
kubectl get resourcequota -n helm-test-dryrun

# Verify chart exceeds quota
helm template test-quota ./quota-violation | grep -A 5 "resources:"

# Server rejects due to quota
helm install test-quota ./quota-violation -n helm-test-dryrun --dry-run=server 2>&1 | grep -i "quota\|exceeded"
```

**Cleanup**:
```bash
kubectl delete resourcequota test-quota -n helm-test-dryrun
```

---

### DR-005: RBAC Permission Issues

**Description**: Test detection of RBAC permission issues during deployment.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-dryrun

# Create service account with limited permissions
kubectl create serviceaccount limited-sa -n helm-test-dryrun
```

**Test Steps**:
```bash
# 1. Attempt to deploy chart with service account lacking permissions
helm install test-rbac ./rbac-restricted -n helm-test-dryrun \
  --set serviceAccount.name=limited-sa --dry-run=server
```

**Expected Behavior**:
- Server-side dry-run may succeed (checks chart, not SA permissions)
- Actual deployment would fail
- Script shows RBAC-related resources
- Suggests checking service account permissions

**Validation**:
```bash
# Check service account exists
kubectl get sa limited-sa -n helm-test-dryrun

# Check RBAC permissions
kubectl auth can-i create secrets --as=system:serviceaccount:helm-test-dryrun:limited-sa -n helm-test-dryrun

# Check chart requires permissions SA doesn't have
helm template test-rbac ./rbac-restricted | grep -i "kind.*Role"
```

**Cleanup**:
```bash
kubectl delete serviceaccount limited-sa -n helm-test-dryrun
```

---

## Test Failures

### TF-001: Helm Test Failures

**Description**: Test detection when helm test command fails.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-tests
```

**Test Steps**:
```bash
# 1. Deploy chart with failing test
helm install test-fail-test ./test-failure -n helm-test-tests

# 2. Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-tests --timeout=60s

# 3. Run helm test
helm test test-fail-test -n helm-test-tests --logs

# 4. Run debug script with test option
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-fail-test helm-test-tests --run-tests
```

**Expected Behavior**:
- Release deploys successfully
- Helm test fails
- Test pod exits with non-zero code
- Test logs show failure reason
- Script identifies test failure

**Validation**:
```bash
# Verify app is running
kubectl get pods -n helm-test-tests -l app=test-app

# Verify test failed
kubectl get pods -n helm-test-tests -l "helm.sh/hook=test"

# Check test logs
kubectl logs -n helm-test-tests -l "helm.sh/hook=test"
```

**Cleanup**:
```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-fail-test -n helm-test-tests
```

---

### TF-002: Test Pod Timeout

**Description**: Test detection when test pod times out.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-tests
```

**Test Steps**:
```bash
# 1. Deploy chart with long-running test
helm install test-timeout-test ./test-timeout -n helm-test-tests

# 2. Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-tests --timeout=60s

# 3. Run helm test with short timeout
helm test test-timeout-test -n helm-test-tests --timeout 30s

# 4. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-timeout-test helm-test-tests --run-tests
```

**Expected Behavior**:
- Test times out
- Helm test command returns timeout error
- Test pod may still be running
- Script identifies timeout issue

**Validation**:
```bash
# Check test pod status
kubectl get pods -n helm-test-tests -l "helm.sh/hook=test"

# Check test pod logs (may show incomplete test)
kubectl logs -n helm-test-tests -l "helm.sh/hook=test"
```

**Cleanup**:
```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-timeout-test -n helm-test-tests
```

---

### TF-003: Test Pod ImagePullBackOff

**Description**: Test detection when test pod cannot pull image.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-tests
```

**Test Steps**:
```bash
# 1. Deploy chart with test using non-existent image
helm install test-imagepull ./test-imagepull -n helm-test-tests

# 2. Wait for deployment
kubectl wait --for=condition=ready pod -l app=test-app -n helm-test-tests --timeout=60s

# 3. Attempt helm test
helm test test-imagepull -n helm-test-tests --logs

# 4. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-imagepull helm-test-tests --run-tests
```

**Expected Behavior**:
- App deploys successfully
- Test pod shows ImagePullBackOff
- Events show image pull errors
- Test never runs
- Script identifies image pull issue

**Validation**:
```bash
# Verify test pod in ImagePullBackOff
kubectl get pods -n helm-test-tests -l "helm.sh/hook=test"

# Check events
kubectl get events -n helm-test-tests --sort-by='.lastTimestamp' | grep -i "pull\|image"

# Describe test pod
kubectl describe pod -n helm-test-tests -l "helm.sh/hook=test" | grep -A 5 Events
```

**Cleanup**:
```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-imagepull -n helm-test-tests
```

---

### TF-004: Service Not Ready During Tests

**Description**: Test detection when test runs before service is ready.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-tests
```

**Test Steps**:
```bash
# 1. Deploy chart with slow-starting service
helm install test-service-not-ready ./test-service-not-ready -n helm-test-tests

# 2. Run test immediately (before service ready)
helm test test-service-not-ready -n helm-test-tests --logs

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-service-not-ready helm-test-tests --run-tests
```

**Expected Behavior**:
- Test fails with connection refused
- Service exists but endpoints not ready
- Test logs show connection errors
- Script identifies service readiness issue

**Validation**:
```bash
# Check service exists
kubectl get svc -n helm-test-tests

# Check endpoints
kubectl get endpoints -n helm-test-tests

# Verify test failed with connection error
kubectl logs -n helm-test-tests -l "helm.sh/hook=test" | grep -i "connection\|refused\|timeout"
```

**Cleanup**:
```bash
kubectl delete pods -n helm-test-tests -l "helm.sh/hook=test"
helm uninstall test-service-not-ready -n helm-test-tests
```

---

## Other Scenarios

### OS-001: Resource Name Conflicts

**Description**: Test detection when resource names conflict with existing resources.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-validation
```

**Test Steps**:
```bash
# 1. Create a conflicting resource manually
kubectl create deployment conflict-test --image=nginx -n helm-test-validation

# 2. Attempt to install chart with same resource name
helm install test-conflict ./resource-conflict -n helm-test-validation

# 3. Run debug script (will fail to create release)
# Note: Release may not exist if install failed early
```

**Expected Behavior**:
- Installation fails
- Error shows resource already exists
- Helm cannot take ownership
- Clear conflict message

**Validation**:
```bash
# Verify existing resource
kubectl get deployment conflict-test -n helm-test-validation

# Verify helm install failed
helm list -n helm-test-validation --all | grep test-conflict || echo "Release not created"

# Check error message
helm install test-conflict ./resource-conflict -n helm-test-validation 2>&1 | grep -i "already exists\|conflict"
```

**Cleanup**:
```bash
kubectl delete deployment conflict-test -n helm-test-validation
helm uninstall test-conflict -n helm-test-validation 2>/dev/null || true
```

---

### OS-002: Database Migration Failures

**Description**: Test detection when database migration hook fails.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-hooks
```

**Test Steps**:
```bash
# 1. Deploy chart with failing database migration hook
helm install test-db-migration ./db-migration-fail -n helm-test-hooks

# 2. Wait for hook to fail
sleep 30

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-db-migration helm-test-hooks
```

**Expected Behavior**:
- Release stuck in pending-install
- Pre-install migration hook failed
- Hook logs show database connection or migration errors
- Main app not deployed
- Script identifies migration hook failure

**Validation**:
```bash
# Verify migration hook failed
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=pre-install,job=migration"

# Check migration logs
kubectl logs -n helm-test-hooks -l "helm.sh/hook=pre-install,job=migration"

# Verify app not deployed
kubectl get pods -n helm-test-hooks -l app=test-app | grep -i running || echo "App not running"
```

**Cleanup**:
```bash
kubectl delete jobs -n helm-test-hooks -l "helm.sh/hook=pre-install"
helm uninstall test-db-migration -n helm-test-hooks
```

---

### OS-003: Configuration Errors

**Description**: Test detection of configuration errors in deployed application.

**Prerequisites**:
```bash
kubectl config set-context --current --namespace=helm-test-states
```

**Test Steps**:
```bash
# 1. Deploy chart with invalid configuration
helm install test-config-error ./config-error -n helm-test-states

# 2. Wait for pods to fail
sleep 30

# 3. Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-config-error helm-test-states
```

**Expected Behavior**:
- Release shows deployed
- Pods are CrashLoopBackOff
- Pod logs show configuration errors
- ConfigMap/Secret exists but has invalid values
- Script identifies pod failures and shows logs

**Validation**:
```bash
# Verify pods crashing
kubectl get pods -n helm-test-states -l app=test-app

# Check pod logs for config error
kubectl logs -n helm-test-states -l app=test-app | grep -i "config\|error\|invalid"

# Verify ConfigMap exists
kubectl get configmap -n helm-test-states
```

**Cleanup**:
```bash
helm uninstall test-config-error -n helm-test-states
kubectl delete pods -n helm-test-states --all
```

---

## Automated Test Execution

### Running All Tests

Use the provided automation script to run all tests:

```bash
# Run all tests
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh

# Run specific category
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh --category hooks

# Run specific test
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh --test HF-001

# Run in verbose mode
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh --verbose

# Skip cleanup (for debugging)
/Users/rbias/code/k8s4agents/scratch/run-helm-debug-tests.sh --no-cleanup
```

### Test Results

Tests output results in the following format:

```
========================================
Test: HF-001 - Pre-Install Hook Failure
========================================
Status: PASS
Duration: 45s
Details: Successfully detected pre-install hook failure

Checks:
✓ Release in failed/pending state
✓ Hook job shows failed status
✓ Hook logs captured
✓ Script identified issue
✓ Cleanup successful
```

### Continuous Integration

Example GitHub Actions workflow:

```yaml
name: Helm Debug Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Create k3s cluster
        uses: debianmaster/actions-k3s@master

      - name: Install Helm
        uses: azure/setup-helm@v3

      - name: Run test suite
        run: |
          ./scratch/run-helm-debug-tests.sh --verbose

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results/
```

---

## Test Maintenance

### Adding New Tests

To add a new test scenario:

1. Create test chart in `/Users/rbias/code/k8s4agents/scratch/test-charts/`
2. Add test case to this document following the template
3. Update `run-helm-debug-tests.sh` to include new test
4. Verify test can run independently and with full suite

### Test Chart Requirements

Each test chart should:
- Have a unique name
- Include README.md explaining its purpose
- Be self-contained (no external dependencies)
- Include values.yaml with sensible defaults
- Clean up properly (use appropriate delete policies)

### Updating Tests

When updating `helm_release_debug.sh` script:
1. Review existing tests for affected scenarios
2. Update test expectations as needed
3. Add new tests for new detection capabilities
4. Run full test suite to verify no regressions

---

## Troubleshooting the Tests

### Test Hangs or Times Out

```bash
# Kill stuck resources
kubectl delete namespace helm-test-hooks --force --grace-period=0
kubectl delete namespace helm-test-states --force --grace-period=0

# Recreate namespaces
kubectl create namespace helm-test-hooks
```

### Test Cleanup Fails

```bash
# Force cleanup all test namespaces
for ns in helm-test-hooks helm-test-states helm-test-validation helm-test-dryrun helm-test-tests; do
  kubectl delete namespace $ns --force --grace-period=0 2>/dev/null || true
  kubectl create namespace $ns
done

# Remove any stuck finalizers
kubectl get namespace helm-test-hooks -o json | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/helm-test-hooks/finalize" -f -
```

### Cluster State Polluted

```bash
# Complete cluster reset (use with caution!)
# This removes all test resources
kubectl delete namespace --selector=name=~helm-test.*

# Or reset specific namespace
kubectl delete namespace helm-test-hooks
kubectl create namespace helm-test-hooks
```

---

## Success Criteria

A test passes if:
1. Failure condition is successfully induced
2. `helm_release_debug.sh` script detects the issue
3. Script output includes relevant diagnostic information
4. Validation steps confirm expected behavior
5. Cleanup completes without errors
6. Test can be run repeatedly with consistent results

## Test Coverage Matrix

| Category | Scenarios | Priority | Status |
|----------|-----------|----------|--------|
| Hook Failures | 7 | High | Ready |
| Release States | 5 | High | Ready |
| Chart Validation | 6 | High | Ready |
| Dry-Run Issues | 5 | Medium | Ready |
| Test Failures | 4 | Medium | Ready |
| Other Scenarios | 3 | Low | Ready |
| **Total** | **30** | - | **Ready** |

---

## Appendix

### Environment Variables

```bash
# Set these for consistent test execution
export HELM_DEBUG_SCRIPT="/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh"
export TEST_CHARTS_DIR="/Users/rbias/code/k8s4agents/scratch/test-charts"
export TEST_TIMEOUT="120s"
```

### Quick Reference Commands

```bash
# Clean all test namespaces
kubectl delete namespace --selector="purpose=helm-testing"

# List all test releases
helm list --all-namespaces | grep test-

# Remove all test releases
helm list --all-namespaces -o json | jq -r '.[] | select(.name | startswith("test-")) | "\(.name) \(.namespace)"' | while read name ns; do helm uninstall $name -n $ns; done

# Check for stuck resources
kubectl get all --all-namespaces | grep helm-test
```

### Related Documentation

- Helm Debugging Guide: `/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/references/helm-debugging.md`
- helm_release_debug.sh Script: `/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh`
- Kubernetes Troubleshooting: `/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/SKILL.md`

---

**Document Version**: 1.0
**Last Updated**: 2025-12-16
**Maintainer**: K8s4Agents Project
