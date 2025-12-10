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

## Quick Start: Slash Commands

Use these trigger patterns for fast workflow access:

- `/pod-debug` - Pod not starting or crashing
- `/svc-debug` - Service unreachable or DNS issues
- `/storage-debug` - PVC pending or mount failures
- `/network-debug` - Connectivity or network policy issues
- `/node-debug` - Node NotReady or resource pressure
- `/helm-debug` - Helm deployment or upgrade failures
- `/full-diag` - Comprehensive cluster health check
- `/cluster-assessment` - Generate comprehensive cluster assessment report

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

## Workflow 1: Pod Troubleshooting (/pod-debug)

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

## Workflow 2: Service Connectivity (/svc-debug)

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

## Workflow 3: Storage Troubleshooting (/storage-debug)

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

## Workflow 4: Node Health (/node-debug)

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

## Workflow 5: Helm Debugging (/helm-debug)

### Phase 1: Release Status

```bash
# List releases
helm list -n <NAMESPACE>

# Get release status
helm status <RELEASE_NAME> -n <NAMESPACE>

# Check release history
helm history <RELEASE_NAME> -n <NAMESPACE>
```

### Phase 2: Template Validation

```bash
# Lint chart
helm lint <CHART_PATH>

# Render templates without installing
helm template <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --values <VALUES_FILE>

# Dry-run install/upgrade
helm upgrade --install <RELEASE_NAME> <CHART_PATH> -n <NAMESPACE> --dry-run --debug
```

### Phase 3: Stuck Release Recovery

```bash
# Check for pending upgrades
helm list -n <NAMESPACE> --pending

# Check release secrets
kubectl get secrets -n <NAMESPACE> -l owner=helm

# Check deployed resources
helm get manifest <RELEASE_NAME> -n <NAMESPACE> | kubectl get -f -
```

**Deep Dive**: See `references/helm-debugging.md` for upgrade failures, rollback procedures, and secret/state cleanup.

## Workflow 6: Cluster Health (/full-diag)

### Phase 1: Control Plane Check

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

### Phase 2: Cluster Resource Overview

```bash
# Node summary
kubectl get nodes

# Cluster resource usage
kubectl top nodes
kubectl top pods --all-namespaces | head -20

# Check for resource quotas
kubectl get resourcequotas --all-namespaces
```

### Phase 3: System Pod Health

```bash
# Check critical system pods
kubectl get pods -n kube-system -o wide

# Check for recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50

# Check for failed pods cluster-wide
kubectl get pods --all-namespaces --field-selector status.phase=Failed
```

**Script Available**: `scripts/cluster_health_check.sh` automates this workflow.

## Workflow 7: Cluster Assessment (/cluster-assessment)

### Overview

Generate a comprehensive, documented cluster assessment report for audits, capacity planning, and documentation. Unlike the quick health check above, this produces a detailed markdown report with analysis and recommendations.

### When to Use

- **Initial cluster evaluation**: Baseline assessment of new clusters
- **Capacity planning**: Understanding resource utilization and growth
- **Audit and compliance**: Documentation for security reviews
- **Quarterly reviews**: Regular operational health assessments
- **Handoff documentation**: Transferring cluster ownership

### Assessment Phases

**Phase 1: Data Collection**
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

**Phase 2: Analysis**

The assessment analyzes:
- Resource overcommitment (CPU/Memory limits vs capacity)
- Failed or pending workloads
- Node pressure conditions
- Security posture (network policies, RBAC, authentication)
- Storage capacity and health
- Platform component status

**Phase 3: Report Generation**

Generates structured markdown report with:
- Executive summary with health score
- Detailed analysis of all cluster aspects
- Prioritized recommendations (High/Medium/Low)
- Comparison against best practices

**Phase 4: Recommendations**

Each finding includes:
- Problem statement
- Impact assessment
- Specific action items
- Documentation references

### Using the Assessment Script

```bash
# Generate report with default name (cluster-assessment-TIMESTAMP.md)
./scripts/cluster_assessment.sh

# Specify output file
./scripts/cluster_assessment.sh -o my-cluster-report.md

# Use specific kubeconfig
./scripts/cluster_assessment.sh -c ~/.kube/prod-config -o prod-report.md
```

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

## Network Debugging Workflow (/network-debug)

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

For common scenarios, see `references/incident-playbooks.md`:

- **CrashLoopBackOff**: Application crash recovery workflow
- **OOMKilled**: Memory pressure investigation and tuning
- **DNS Failures**: CoreDNS troubleshooting and resolution
- **Node Pressure**: Disk, memory, PID pressure handling
- **ImagePullBackOff**: Registry access and authentication
- **Pending Pods**: Scheduling failures and resource constraints
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

Available diagnostic scripts in `scripts/`:

- `cluster_health_check.sh`: Automated baseline cluster health check
- `pod_diagnostics.sh`: Comprehensive pod state analysis
- `network_debug.sh`: DNS, endpoints, and connectivity testing
- `storage_check.sh`: PVC/PV and CSI driver diagnostics
- `helm_release_debug.sh`: Helm release investigation

## Additional Resources

**References**:
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
