---
name: k8s-troubleshooter
description: |
  Comprehensive Kubernetes troubleshooting skill for diagnosing cluster, workload, networking, storage, and Helm issues.
  Provides systematic diagnostic workflows, production-safe command patterns, and incident response playbooks.
  Covers pod lifecycle issues, service connectivity, DNS problems, storage/CSI failures, node health, CNI/Calico
  troubleshooting, Helm debugging, and cluster-wide diagnostics. Uses symptom-based entry points with phased triage
  (baseline → inspect → correlate → deep dive). All commands are read-only by default for production safety.
---

# Kubernetes Troubleshooter Skill

## Overview

This skill encodes expert Kubernetes troubleshooting workflows for diagnosing complex cluster issues. It provides systematic investigation methodologies, production-safe diagnostic patterns, and incident response playbooks that guide you through identifying root causes rather than just treating symptoms.

**Core Capabilities**:
- Pod lifecycle diagnostics (Pending, CrashLoopBackOff, OOMKilled, ImagePull failures)
- Service connectivity and DNS troubleshooting
- Storage/CSI and PVC/PV issues
- Node health and resource pressure
- Network policy and CNI (Calico) debugging
- Helm chart and release troubleshooting
- Cluster-wide health checks and control plane diagnostics

**Safety First**: All diagnostic commands are read-only unless explicitly marked as remediation. This prevents making production incidents worse while investigating.

**Progressive Disclosure**: Core workflows are in this file. Deep dives available in `references/` when needed.

## Incident Response (Start Here for Production Issues)

**When to use**: Any production incident, outage, or unexpected cluster behavior.

### Automated Incident Triage (Primary Method)

```bash
# Run comprehensive incident triage
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh

# Quick triage without full cluster dump (faster, recommended for urgent incidents)
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --skip-dump

# Scope to specific namespace
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --namespace production

# Custom output directory
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --output-dir /tmp/incident-20231201
```

The incident triage script:
1. **Captures evidence** - Preserves cluster state before investigation (nodes, pods, events, optional cluster-info dump)
2. **Checks control plane** - Uses `/readyz?verbose` for component-level health status
3. **Assesses blast radius** - Classifies impact: single pod, namespace, multiple namespaces, or cluster-wide
4. **Classifies symptoms** - Detects crash loops, OOM, scheduling failures, DNS/network issues, storage problems
5. **Recommends workflows** - Provides specific diagnostic scripts and commands based on detected symptoms
6. **Generates report** - Creates markdown report with executive summary and text summary for quick reference

**Output**: Triage report with blast radius, symptoms, recommended next steps, and captured evidence.

**Use this FIRST** when responding to production incidents. It provides the systematic assessment needed to guide investigation without making the situation worse.

### Decision Tree Quick Reference

See `references/incident-response.md` for complete triage decision tree and investigation workflows.

**Quick symptom-to-workflow mapping**:
- **Pods Pending** → `pod_diagnostics.sh` (check scheduling, resources, taints)
- **CrashLoopBackOff** → `pod_diagnostics.sh -l -p` (check logs, exit codes)
- **OOMKilled** → `pod_diagnostics.sh` (check memory limits, usage)
- **DNS/Network issues** → `network_debug.sh` (check CoreDNS, endpoints, policies)
- **Storage failures** → `storage_check.sh` (check PVC, CSI driver, attachments)
- **Node problems** → `cluster_health_check.sh` (check conditions, pressure)
- **Control plane degraded** → `cluster_health_check.sh` (check components, API server)

### First 5 Minutes Checklist

When a production incident is reported:

1. **Assess urgency** - Can you access the cluster? Are users impacted?
2. **Run incident triage** - `incident_triage.sh --skip-dump` for fast assessment
3. **Stabilize if critical** - Consider immediate actions (scale, rollback) only if necessary
4. **Preserve evidence** - Triage script captures this automatically
5. **Follow recommendations** - Use triage report to guide investigation

**Remember**: Evidence first, action second. The triage script preserves state before changes.

## Automation First

**Priority**: Use automation scripts before manual command workflows. Scripts provide production-tested diagnostic flows and generate structured output.

### Quick Reference: Task to Script Mapping

| Task | Script | Invocation |
|------|--------|------------|
| **Production incident triage** | `incident_triage.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --skip-dump` |
| Incident triage (with cluster dump) | `incident_triage.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh` |
| Incident triage (namespace-scoped) | `incident_triage.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --namespace <NAMESPACE>` |
| Cluster health check | `cluster_health_check.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/cluster_health_check.sh` |
| Cluster assessment report | `cluster_assessment.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh` |
| Cluster assessment (custom output) | `cluster_assessment.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh -o custom-report.md` |
| Cluster assessment (custom kubeconfig) | `cluster_assessment.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh -c ~/.kube/prod-config` |
| Pod diagnostics | `pod_diagnostics.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/pod_diagnostics.sh <POD_NAME> <NAMESPACE>` |
| Network debugging | `network_debug.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/network_debug.sh <NAMESPACE>` |
| Storage check | `storage_check.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/storage_check.sh <NAMESPACE>` |
| Helm release debug (basic) | `helm_release_debug.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE>` |
| Helm release with chart validation | `helm_release_debug.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> --chart <CHART_PATH> --values <VALUES_FILE>` |
| Helm release with tests | `helm_release_debug.sh` | `~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> --run-tests` |

**Script Location**: All scripts are in `~/.claude/skills/k8s-troubleshooter/scripts/`

**Getting Help**: Run any script with `-h` flag for usage details and parameters.

**When to Use Manual Commands**: Use manual workflows when:
- Script is not available for your specific task
- You need to understand the diagnostic methodology
- Script fails and you need to debug the underlying commands

## Diagnostic Decision Tree

Start with the symptom that best matches your issue:

```
Issue Category → Entry Point → Workflow Phase
├─ Pod Issues
│  ├─ Not starting (Pending) → Pod Lifecycle → Baseline
│  ├─ Crashing (CrashLoop) → Pod Lifecycle → Inspect
│  ├─ Image pull failures → Pod Lifecycle → Correlate
│  └─ Resource issues (OOM) → Pod Lifecycle → Deep Dive
├─ Service/Network Issues
│  ├─ DNS resolution → Service Connectivity → Baseline
│  ├─ Endpoint mismatches → Service Connectivity → Inspect
│  ├─ Network policies → Network Debugging → Correlate
│  └─ Ingress/LoadBalancer → Service Connectivity → Deep Dive
├─ Storage Issues
│  ├─ PVC pending → Storage Diagnostics → Baseline
│  ├─ Mount failures → Storage Diagnostics → Inspect
│  ├─ CSI driver errors → Storage Diagnostics → Correlate
│  └─ Cloud provider issues → Storage Diagnostics → Deep Dive
├─ Node Issues
│  ├─ NotReady → Node Health → Baseline
│  ├─ Resource pressure → Node Health → Inspect
│  ├─ Kubelet issues → Node Health → Correlate
│  └─ CNI failures → Node Health → Deep Dive
├─ Helm Issues
│  ├─ Install/upgrade failures → Helm Debugging → Baseline
│  ├─ Stuck releases → Helm Debugging → Inspect
│  └─ Template errors → Helm Debugging → Correlate
└─ Cluster-Wide Issues
   ├─ API server problems → Cluster Health → Baseline
   ├─ Control plane → Cluster Health → Inspect
   └─ Authentication/RBAC → Cluster Health → Correlate
```

## Workflow 1: Pod Troubleshooting

### Phase 1: Baseline Assessment

**Objective**: Determine pod current state and recent events

```bash
# Get pod status and basic info
kubectl get pod <POD_NAME> -n <NAMESPACE> -o wide

# Check recent events
kubectl get events -n <NAMESPACE> --field-selector involvedObject.name=<POD_NAME> --sort-by='.lastTimestamp'

# Get pod details
kubectl describe pod <POD_NAME> -n <NAMESPACE>
```

**Common States**:
- `Pending`: Scheduling or resource issues
- `CrashLoopBackOff`: Container repeatedly failing
- `ImagePullBackOff` / `ErrImagePull`: Image retrieval problems
- `Running` but unhealthy: Readiness/liveness probe failures
- `Terminating` stuck: Finalizers or graceful shutdown issues

### Phase 2: Inspect Container Status

**For Pending Pods**:
```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check pod resource requests
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources}'

# Check for taints and tolerations
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.tolerations}'
```

**For CrashLoopBackOff**:
```bash
# Get current logs
kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER_NAME>

# Get previous container logs (after crash)
kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER_NAME> --previous

# Check exit code and reason
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].lastState.terminated}'
```

**For Image Pull Failures**:
```bash
# Verify image name and tag
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].image}'

# Check imagePullSecrets
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.imagePullSecrets}'

# Test image pull on node
kubectl debug node/<NODE_NAME> -it --image=<TEST_IMAGE>
```

### Phase 3: Correlate with Dependencies

```bash
# Check ConfigMaps and Secrets
kubectl get configmaps,secrets -n <NAMESPACE>
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 5 "Environment"

# Check PVC bindings
kubectl get pvc -n <NAMESPACE>
kubectl describe pvc <PVC_NAME> -n <NAMESPACE>

# Check service account and RBAC
kubectl get serviceaccount <SA_NAME> -n <NAMESPACE>
kubectl auth can-i --list --as=system:serviceaccount:<NAMESPACE>:<SA_NAME>
```

### Phase 4: Deep Dive (Advanced)

See `references/pod-troubleshooting.md` for:
- Container startup probe debugging
- Init container sequencing
- Resource quota and limit ranges
- Pod disruption budgets
- Security context issues
- Image pull through proxies

**Stop Conditions**: Pod running and passing readiness checks, or root cause identified.

## Workflow 2: Service Connectivity

### Phase 1: Baseline Assessment

```bash
# Check service definition
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o wide

# Check endpoints
kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE>

# Verify selector matches pods
kubectl get pods -n <NAMESPACE> -l <SELECTOR> --show-labels
```

### Phase 2: DNS Verification

```bash
# Test DNS resolution from within cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

### Phase 3: Endpoint Investigation

```bash
# Detailed endpoint info
kubectl describe endpoints <SERVICE_NAME> -n <NAMESPACE>

# Check pod readiness
kubectl get pods -n <NAMESPACE> -l <SELECTOR> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# Test direct pod connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl <POD_IP>:<PORT>
```

### Phase 4: Network Policy Check

```bash
# List network policies affecting namespace
kubectl get networkpolicies -n <NAMESPACE>

# Describe relevant policies
kubectl describe networkpolicy <POLICY_NAME> -n <NAMESPACE>

# Check pod labels against policy selectors
kubectl get pods -n <NAMESPACE> --show-labels
```

**Deep Dive**: See `references/service-networking.md` for ingress troubleshooting, LoadBalancer issues, ExternalDNS, and service mesh integration.

## Workflow 3: Storage Troubleshooting

### Phase 1: PVC Status Check

```bash
# Check PVC status
kubectl get pvc -n <NAMESPACE>

# Detailed PVC info
kubectl describe pvc <PVC_NAME> -n <NAMESPACE>

# Check PV binding
kubectl get pv
kubectl describe pv <PV_NAME>
```

### Phase 2: StorageClass and Provisioner

```bash
# Check StorageClass
kubectl get storageclass
kubectl describe storageclass <SC_NAME>

# Check CSI driver pods
kubectl get pods -n kube-system | grep csi

# Check CSI controller logs
kubectl logs -n kube-system <CSI_CONTROLLER_POD> -c csi-provisioner
```

### Phase 3: Volume Attachment

```bash
# Check volume attachments
kubectl get volumeattachments

# Describe specific attachment
kubectl describe volumeattachment <ATTACHMENT_NAME>

# Check node volume health
kubectl describe node <NODE_NAME> | grep -A 10 "Volumes"
```

**Deep Dive**: See `references/storage-csi.md` for cloud-specific CSI troubleshooting (EBS, Azure Disk, GCE PD), mount options, and performance issues.

## Workflow 4: Node Health

### Phase 1: Node Status

```bash
# Check node status
kubectl get nodes -o wide

# Check node conditions
kubectl describe node <NODE_NAME> | grep -A 10 "Conditions"

# Check resource pressure
kubectl top nodes
kubectl describe node <NODE_NAME> | grep -A 5 "Allocated resources"
```

### Phase 2: Kubelet and System Services

```bash
# Check kubelet logs (node access required)
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host journalctl -u kubelet -n 100

# Check container runtime
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host systemctl status containerd

# Check CNI health
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host ls -la /etc/cni/net.d/
```

### Phase 3: Pod Distribution and Eviction

```bash
# List pods on node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<NODE_NAME>

# Check for evicted pods
kubectl get pods --all-namespaces --field-selector status.phase=Failed

# Check pod disruption budgets
kubectl get pdb --all-namespaces
```

**Deep Dive**: See `references/calico-cni.md` for Calico-specific troubleshooting.

## Workflow 5: Helm Debugging

> **AUTOMATED SCRIPT AVAILABLE**: Use `helm_release_debug.sh` for comprehensive Helm release diagnostics.

### Automated Helm Debug (Primary Method)

```bash
# Basic release diagnostics
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE>

# Include chart validation (lint, template, dry-run)
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> \
  --chart <CHART_PATH> --values <VALUES_FILE>

# Run post-install tests with the release
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> --run-tests

# Full validation: chart lint, template, dry-run, and tests
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> \
  --chart <CHART_PATH> --values <VALUES_FILE> --run-tests --run-dry-run

# Compare current release with proposed changes
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> \
  --chart <CHART_PATH> --values <VALUES_FILE> --diff

# Custom output format (json, yaml, table)
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> --output json
```

The script automatically provides:

**Core Diagnostics** (always included):
- Release status, history, and current values
- Deployed resource status and health
- Hook execution details (jobs, pods, logs)
- Recent events and error messages
- Release state clarity (last_error reporting, empty manifest detection)
- Helm secret validation
- Pod status with standard Helm labels

**Hook-Aware Diagnostics**:
- Lists all hooks defined in the release (`helm get hooks`)
- Shows hook job and pod details
- Displays hook execution logs
- Identifies failed hook phases (pre-install, post-install, pre-upgrade, post-upgrade, pre-delete, post-delete)
- Reports aged-out events for hooks

**Optional Chart Validation** (with `--chart` flag):
- Chart linting (`helm lint`) with detailed error reporting
- Template rendering (`helm template`) to catch syntax errors
- Dry-run installation/upgrade (`helm upgrade --dry-run --debug`) with `--run-dry-run` flag
- Value file validation and override testing with `--set*` flags
- Diff comparison between current and proposed release with `--diff` flag

**Optional Post-Install Tests** (with `--run-tests` flag):
- Executes `helm test` for the release
- Provides failure summaries with test pod details
- Shows test logs for failed tests
- Reports test execution timeout issues

### When to Use Each Flag

**Basic Diagnostics** (no flags):
- Release is stuck or failed
- Need to understand current release state
- Checking deployed resource health
- Initial troubleshooting phase

**`--chart <PATH> --values <FILE>`** (Chart Validation):
- Before performing an upgrade
- Template rendering errors suspected
- Validating chart syntax changes
- Testing value overrides
- Use when you have access to chart files

**`--run-dry-run`** (with `--chart`):
- Want to see what would change without applying
- Testing complex upgrades
- Validating cluster-side mutations (admission webhooks, mutating webhooks)
- Checking API compatibility

**`--diff`** (with `--chart`):
- Need to see exact changes between current and proposed release
- Reviewing impact of value changes
- Understanding configuration drift
- Pre-upgrade review

**`--run-tests`**:
- Release deployed but functionality uncertain
- Post-upgrade validation
- Smoke testing after remediation
- Continuous validation in CI/CD

**`--set*` flags** (`--set`, `--set-string`, `--set-file`):
- Quick value overrides without modifying values file
- Testing specific configuration changes
- Override single values for validation

**`--output <format>`** (json, yaml, table):
- Integrating with automation or CI/CD
- Parsing output programmatically
- Generating structured reports

### Usage Examples

**Scenario 1: Failed Helm Upgrade**
```bash
# Start with basic diagnostics
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production

# If template issues suspected, validate chart
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production \
  --chart ./charts/myapp --values values-prod.yaml
```

**Scenario 2: Release Stuck in Pending-Upgrade**
```bash
# Check release state and hooks
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production

# Review what would happen on retry with dry-run
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production \
  --chart ./charts/myapp --values values-prod.yaml --run-dry-run
```

**Scenario 3: Post-Upgrade Validation**
```bash
# Run tests to verify functionality
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production --run-tests

# Check difference from previous version
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production \
  --chart ./charts/myapp --values values-prod.yaml --diff
```

**Scenario 4: Pre-Upgrade Review**
```bash
# Full validation before upgrade
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production \
  --chart ./charts/myapp-v2 --values values-prod.yaml \
  --run-dry-run --diff --run-tests
```

**Scenario 5: Hook Failure Investigation**
```bash
# Script automatically shows hook details including:
# - Hook definitions from release
# - Hook job/pod status
# - Hook execution logs
# - Failed hook phases
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh myapp production
```

### Manual Fallback (when script unavailable)

#### Phase 1: Release Status

```bash
# List releases
helm list -n <NAMESPACE>

# Get release status
helm status <RELEASE_NAME> -n <NAMESPACE>

# Check release history
helm history <RELEASE_NAME> -n <NAMESPACE>

# Check for release errors
helm status <RELEASE_NAME> -n <NAMESPACE> -o json | jq '.info.status, .info.description'
```

#### Phase 2: Template Validation

```bash
# Lint chart
helm lint <CHART_PATH>

# Render templates without installing
helm template <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --values <VALUES_FILE>

# Dry-run install/upgrade
helm upgrade --install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run --debug

# Show diff between releases
helm diff upgrade <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --values <VALUES_FILE>
```

#### Phase 3: Hook Diagnostics

```bash
# Get hooks for release
helm get hooks <RELEASE_NAME> -n <NAMESPACE>

# Check hook job status
kubectl get jobs -n <NAMESPACE> -l app.kubernetes.io/managed-by=Helm

# Get hook pod logs
kubectl logs -n <NAMESPACE> -l app.kubernetes.io/managed-by=Helm --tail=100
```

#### Phase 4: Stuck Release Recovery

```bash
# Check for pending upgrades
helm list -n <NAMESPACE> --pending

# Check release secrets
kubectl get secrets -n <NAMESPACE> -l owner=helm

# Check deployed resources
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl get -f -

# Run post-install tests
helm test <RELEASE_NAME> -n <NAMESPACE>
```

### Release State Clarity

The script provides clear reporting on:

**Empty Manifest Detection**:
- Warns when release has no deployed resources
- Helps identify chart configuration issues
- Indicates potential template rendering problems

**Last Error Reporting**:
- Shows error from most recent failed operation
- Includes error messages from Helm's perspective
- Helps diagnose why releases are stuck

**Aged-Out Events**:
- Identifies when events have expired (default 1 hour TTL)
- Prevents confusion from missing event data
- Recommends checking Helm release history instead

**Hook State Tracking**:
- Shows which hooks succeeded/failed
- Reports hook execution order
- Identifies hanging or incomplete hooks

**Deep Dive**: See `references/helm-debugging.md` for upgrade failures, rollback procedures, and secret/state cleanup.

## Workflow 6: Cluster Health

> **AUTOMATED SCRIPT AVAILABLE**: Use `cluster_health_check.sh` for quick baseline health checks.

### Automated Health Check (Primary Method)

```bash
# Run automated cluster health check
~/.claude/skills/k8s-troubleshooter/scripts/cluster_health_check.sh
```

This script automatically checks:
- Control plane health (API server, components)
- Node status and resource pressure
- System pod health (kube-system namespace)
- Recent cluster events and errors
- Failed or pending pods

**Use this first** for fast, consistent health checks.

### Manual Fallback (for understanding or when script unavailable)

#### Phase 1: Control Plane Check

```bash
# Check control plane components
kubectl get componentstatuses  # Deprecated in 1.19+, use below

# Check control plane pods
kubectl get pods -n kube-system

# Check API server health
kubectl get --raw /healthz
kubectl get --raw /livez
kubectl get --raw /readyz
```

#### Phase 2: Cluster Resource Overview

```bash
# Node summary
kubectl get nodes

# Cluster resource usage
kubectl top nodes
kubectl top pods --all-namespaces | head -20

# Check for resource quotas
kubectl get resourcequotas --all-namespaces
```

#### Phase 3: System Pod Health

```bash
# Check critical system pods
kubectl get pods -n kube-system -o wide

# Check for recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50

# Check for failed pods cluster-wide
kubectl get pods --all-namespaces --field-selector status.phase=Failed
```

## Workflow 7: Cluster Assessment

> **AUTOMATED SCRIPT AVAILABLE**: Use `cluster_assessment.sh` to generate comprehensive assessment reports.

### Overview

Generate a comprehensive, documented cluster assessment report for audits, capacity planning, and documentation. Unlike the quick health check above, this produces a detailed markdown report with analysis and recommendations.

### When to Use

- **Initial cluster evaluation**: Baseline assessment of new clusters
- **Capacity planning**: Understanding resource utilization and growth
- **Audit and compliance**: Documentation for security reviews
- **Quarterly reviews**: Regular operational health assessments
- **Handoff documentation**: Transferring cluster ownership

### Automated Assessment (Primary Method)

```bash
# Generate report with default name (cluster-assessment-TIMESTAMP.md)
~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh

# Specify output file
~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh -o my-cluster-report.md

# Use specific kubeconfig
~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh -c ~/.kube/prod-config -o prod-report.md
```

The script automatically:
1. Collects comprehensive cluster data (control plane, nodes, workloads, storage, networking)
2. Analyzes resource overcommitment, failed workloads, node pressure, security posture
3. Generates structured markdown report with executive summary and health score
4. Provides prioritized recommendations (High/Medium/Low) with specific action items

**Use this first** for consistent, thorough assessments with actionable recommendations.

### Manual Fallback (for understanding methodology)

#### Phase 1: Data Collection

```bash
# Control plane health
kubectl get --raw /healthz
kubectl get --raw /readyz
kubectl get --raw /livez

# Comprehensive node data
kubectl get nodes -o wide
kubectl describe nodes
kubectl top nodes

# All workloads
kubectl get pods,deployments,statefulsets,daemonsets --all-namespaces

# Storage infrastructure
kubectl get pvc,pv,storageclass --all-namespaces

# Networking
kubectl get svc,endpoints,networkpolicies --all-namespaces

# Recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

#### Phase 2: Analysis

The assessment analyzes:
- Resource overcommitment (CPU/Memory limits vs capacity)
- Failed or pending workloads
- Node pressure conditions
- Security posture (network policies, RBAC, authentication)
- Storage capacity and health
- Platform component status

#### Phase 3: Report Generation

Generates structured markdown report with:
- Executive summary with health score
- Detailed analysis of all cluster aspects
- Prioritized recommendations (High/Medium/Low)
- Comparison against best practices

#### Phase 4: Recommendations

Each finding includes:
- Problem statement
- Impact assessment
- Specific action items
- Documentation references

### Report Sections

1. **Executive Summary** - Health score, critical findings
2. **Control Plane Health** - API server, components
3. **Node Infrastructure** - Status, capacity, conditions
4. **Resource Allocation** - Overcommitment analysis
5. **Workload Status** - Pods, deployments, health
6. **Storage Infrastructure** - PVC/PV, storage classes
7. **Network Configuration** - CNI, services, policies
8. **Security Posture** - RBAC, authentication, policies
9. **Recent Events** - Warnings, errors, alerts
10. **Recommendations** - Prioritized action items

### Comparison: Health Check vs Assessment

| Feature | Health Check | Cluster Assessment |
|---------|-------------|-------------------|
| Speed | 30 seconds | 2-5 minutes |
| Output | Terminal | Markdown report |
| Scope | Critical issues | Full analysis |
| Recommendations | None | Prioritized |
| Use Case | Quick status | Documentation |

**Deep Dive**: See `references/cluster-assessment.md` for detailed assessment methodology, automation, and best practices.

## Network Debugging Workflow

### CNI and Connectivity

```bash
# Check CNI pods
kubectl get pods -n kube-system -l k8s-app=calico-node  # For Calico
kubectl get pods -n kube-system | grep cni

# Test pod-to-pod connectivity
kubectl run -it --rm netshoot-1 --image=nicolaka/netshoot --restart=Never -- ping <TARGET_POD_IP>

# Check network policies
kubectl get networkpolicies --all-namespaces

# Test service connectivity
kubectl run -it --rm netshoot-2 --image=nicolaka/netshoot --restart=Never -- \
  curl <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local:<PORT>
```

**Deep Dive**: See `references/calico-cni.md` for Calico-specific debugging and `references/service-networking.md` for advanced networking.

## Incident Response Playbooks

For structured incident response workflows, see `references/incident-response.md`:

- **Incident Triage Decision Tree**: Symptom-based classification and workflow selection
- **Evidence Preservation**: Best practices for capturing cluster state
- **Investigation Workflows by Symptom**: Detailed steps for each common failure pattern
  - Pods Pending: Scheduling and resource constraints
  - CrashLoopBackOff: Application crash recovery
  - OOMKilled: Memory pressure investigation
  - DNS/Network Issues: CoreDNS and connectivity troubleshooting
  - Storage Failures: PVC and CSI driver diagnostics
  - Node Problems: NotReady nodes and resource pressure
- **Stabilization Techniques**: Safe remediation actions for production
- **Common Incident Patterns**: Real-world scenarios and responses
- **Post-Incident Review**: Documentation and improvement process

For additional common scenarios, see `references/incident-playbooks.md`:

- **ImagePullBackOff**: Registry access and authentication
- **Stuck Terminating**: Finalizer and graceful shutdown issues

## Production Safety Guidelines

### Read-Only Commands (Safe)
- `kubectl get`, `describe`, `logs`, `top`
- `kubectl auth can-i --list` (RBAC check)
- `kubectl debug node/<NODE>` with read-only operations
- `helm list`, `status`, `history`, `get`

### Remediation Commands (Require Explicit Approval)
- `kubectl delete`, `apply`, `edit`, `patch`
- `kubectl scale`, `rollout restart`
- `kubectl drain`, `cordon`, `uncordon`
- `helm upgrade`, `rollback`, `uninstall`

**Always confirm before running remediation commands in production.**

## MCP Integration

For automated kubectl access, see `references/mcp-integration.md` for:
- MCP server setup with read-only access
- RBAC configuration for diagnostic service accounts
- Security and token hygiene
- Integration patterns with Claude

## Scripts Reference

**Use these scripts first** before running manual command sequences. Scripts provide production-tested workflows with consistent output formatting.

**Script Location**: `~/.claude/skills/k8s-troubleshooter/scripts/`

**Getting Help**: All scripts support `-h` flag for detailed usage information and parameter descriptions.

### Available Scripts

**Incident Triage** (`incident_triage.sh`) **[NEW - USE FIRST FOR INCIDENTS]**
- Production incident response and triage workflow
- Captures evidence, assesses blast radius, classifies symptoms, recommends workflows
- Output: Markdown report with executive summary and captured evidence
```bash
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --skip-dump
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --namespace production
~/.claude/skills/k8s-troubleshooter/scripts/incident_triage.sh --output-dir /tmp/incident-123
```

**Cluster Health Check** (`cluster_health_check.sh`)
- Automated baseline cluster health check
- Checks: control plane, nodes, system pods, recent events
```bash
~/.claude/skills/k8s-troubleshooter/scripts/cluster_health_check.sh
```

**Cluster Assessment** (`cluster_assessment.sh`)
- Generate comprehensive assessment report with recommendations
- Output: Markdown report with executive summary and action items
```bash
~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh
~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh -o custom-report.md
~/.claude/skills/k8s-troubleshooter/scripts/cluster_assessment.sh -c ~/.kube/prod-config
```

**Pod Diagnostics** (`pod_diagnostics.sh`)
- Comprehensive pod state analysis and debugging
- Includes: status, events, logs, resource usage, restart history
```bash
~/.claude/skills/k8s-troubleshooter/scripts/pod_diagnostics.sh <POD_NAME> <NAMESPACE>
```

**Network Debug** (`network_debug.sh`)
- DNS, endpoints, and connectivity testing
- Tests: DNS resolution, service endpoints, network policies, pod-to-pod connectivity
```bash
~/.claude/skills/k8s-troubleshooter/scripts/network_debug.sh <NAMESPACE>
```

**Storage Check** (`storage_check.sh`)
- PVC/PV and CSI driver diagnostics
- Checks: PVC status, bindings, provisioner health, volume attachments
```bash
~/.claude/skills/k8s-troubleshooter/scripts/storage_check.sh <NAMESPACE>
```

**Helm Release Debug** (`helm_release_debug.sh`)
- Comprehensive Helm release diagnostics and troubleshooting
- Core: release status, history, deployed resources, hook diagnostics
- Optional: chart validation (lint, template, dry-run), post-install tests, diff comparison
- Flags: `--chart`, `--values`, `--set*`, `--run-tests`, `--run-dry-run`, `--diff`, `--output`
```bash
# Basic diagnostics
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE>

# With chart validation
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> \
  --chart <CHART_PATH> --values <VALUES_FILE>

# Full validation with tests and dry-run
~/.claude/skills/k8s-troubleshooter/scripts/helm_release_debug.sh <RELEASE_NAME> <NAMESPACE> \
  --chart <CHART_PATH> --values <VALUES_FILE> --run-tests --run-dry-run --diff
```

## Additional Resources

**References**:
- `references/incident-response.md`: **[NEW]** Incident triage decision tree and response workflows
- `references/pod-troubleshooting.md`: Pod lifecycle deep dive
- `references/service-networking.md`: Service and ingress troubleshooting
- `references/storage-csi.md`: Storage and CSI driver diagnostics
- `references/helm-debugging.md`: Helm operations and recovery
- `references/calico-cni.md`: Calico CNI troubleshooting
- `references/incident-playbooks.md`: Common failure scenarios
- `references/mcp-integration.md`: MCP server integration

**External Documentation**:
- [Kubernetes Debugging Documentation](https://kubernetes.io/docs/tasks/debug/)
- [kubectl Debug Reference](https://kubernetes.io/docs/reference/kubectl/debug/)
- [Helm Troubleshooting](https://helm.sh/docs/faq/troubleshooting/)

## Workflow Summary

1. **Identify Symptom**: Use decision tree to find entry point
2. **Run Baseline**: Execute Phase 1 diagnostic commands
3. **Inspect Details**: Phase 2 deep dive into specific component
4. **Correlate Events**: Phase 3 check dependencies and relationships
5. **Deep Dive**: Load relevant reference for advanced diagnostics
6. **Identify Root Cause**: Stop when cause is clear
7. **Propose Remediation**: Suggest fixes (requires approval)
8. **Verify Resolution**: Re-run baseline to confirm fix

Remember: The goal is to identify root causes, not just symptoms. Follow the phases systematically and use references for domain-specific deep dives.
