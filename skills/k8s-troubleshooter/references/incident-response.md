# Kubernetes Incident Response Guide

## Overview

This guide provides a structured approach to responding to Kubernetes production incidents. It follows the industry-standard triage workflow: **Stabilize → Capture Evidence → Isolate Layer → Deep Dive**.

## Quick Reference: First 5 Minutes

When a production incident is reported:

1. **Assess urgency** - Is the control plane accessible? Are users impacted?
2. **Run incident triage** - Execute `incident_triage.sh` for automated assessment
3. **Stabilize if needed** - If critical, consider immediate stabilization (scale, rollback)
4. **Preserve evidence** - Save logs and state before making changes
5. **Follow recommended workflow** - Use triage report to guide investigation

## Incident Triage Decision Tree

```
START: Production Issue Reported
│
├─> Can you access the cluster?
│   ├─ NO → Control plane failure
│   │       → Check: API server endpoint, network connectivity, authentication
│   │       → Escalate: Infrastructure team
│   │
│   └─ YES → Continue to blast radius assessment
│
├─> What is the blast radius?
│   ├─ Entire cluster down
│   │   └─> Check control plane health
│   │       ├─ Control plane unhealthy → Priority: Restore control plane
│   │       │   → Run: cluster_health_check.sh
│   │       │   → Check: etcd, API server, controller manager, scheduler
│   │       │
│   │       └─ Control plane healthy → Infrastructure issue
│   │           → Check: All nodes NotReady, CNI failure, cloud provider outage
│   │           → Run: cluster_health_check.sh
│   │
│   ├─ Multiple namespaces affected
│   │   └─> Cluster-wide workload issue
│   │       ├─ Recent deployment? → Check recent changes, consider rollback
│   │       ├─ Node failures? → Check node status, resource pressure
│   │       └─ Platform issue? → Check CNI, DNS (CoreDNS), storage (CSI)
│   │
│   ├─ Single namespace affected
│   │   └─> Namespace-scoped issue
│   │       ├─ All pods failing? → Check namespace resources, quotas, limits
│   │       ├─ Specific deployment? → Check recent changes to that deployment
│   │       └─ Network/DNS? → Check network policies, service configuration
│   │
│   └─ Single pod/workload affected
│       └─> Application or configuration issue
│           → Run: pod_diagnostics.sh
│           → Check: Logs, events, resource limits, dependencies
│
└─> What are the symptoms?
    ├─ Pods Pending
    │   └─> Scheduling or resource constraints
    │       ├─ Check: Node capacity (CPU/memory/disk)
    │       ├─ Check: Taints and tolerations
    │       ├─ Check: Resource requests vs available capacity
    │       ├─ Check: PVC binding (if storage-related)
    │       └─ Run: pod_diagnostics.sh <POD> <NAMESPACE>
    │
    ├─ Pods CrashLoopBackOff
    │   └─> Application errors or misconfigurations
    │       ├─ Check: Container logs (current and previous)
    │       ├─ Check: Exit codes and termination reasons
    │       ├─ Check: Startup probes, dependencies, ConfigMaps/Secrets
    │       └─ Run: pod_diagnostics.sh <POD> <NAMESPACE> -l -p
    │
    ├─ Pods OOMKilled
    │   └─> Memory pressure or insufficient limits
    │       ├─ Check: Container memory limits vs actual usage
    │       ├─ Check: Application memory leaks
    │       ├─ Check: Node memory pressure
    │       └─ Run: pod_diagnostics.sh <POD> <NAMESPACE>
    │       └─ Consider: Increase memory limits or investigate memory leak
    │
    ├─ ImagePullBackOff / ErrImagePull
    │   └─> Registry access or authentication issues
    │       ├─ Check: Image name and tag are correct
    │       ├─ Check: imagePullSecrets exist and are valid
    │       ├─ Check: Registry accessibility from nodes
    │       ├─ Check: Private registry authentication
    │       └─ Run: pod_diagnostics.sh <POD> <NAMESPACE>
    │
    ├─ Service/DNS issues
    │   └─> Networking or DNS resolution problems
    │       ├─ Check: Service endpoints match pod labels
    │       ├─ Check: CoreDNS pods are running and healthy
    │       ├─ Check: Network policies allowing traffic
    │       ├─ Check: DNS resolution from within cluster
    │       └─ Run: network_debug.sh <NAMESPACE>
    │
    ├─ FailedMount / Storage issues
    │   └─> Storage provisioning or mounting problems
    │       ├─ Check: PVC status (Pending vs Bound)
    │       ├─ Check: StorageClass and CSI driver health
    │       ├─ Check: Volume attachment status
    │       ├─ Check: Node volume limits
    │       └─ Run: storage_check.sh <NAMESPACE>
    │
    ├─ Helm release failures
    │   └─> Chart deployment or upgrade issues
    │       ├─ Check: Release status and history
    │       ├─ Check: Template validation errors
    │       ├─ Check: Stuck releases (pending-install, pending-upgrade)
    │       └─ Run: helm_release_debug.sh <RELEASE> <NAMESPACE>
    │
    └─ Node NotReady or pressure
        └─> Node infrastructure problems
            ├─ Check: Node conditions (DiskPressure, MemoryPressure, PIDPressure)
            ├─ Check: Kubelet logs and status
            ├─ Check: Container runtime health
            ├─ Check: CNI pod status on affected nodes
            └─ Run: cluster_health_check.sh
```

## Evidence Preservation Best Practices

**Critical**: Always preserve evidence before making changes to the cluster.

### Automated Evidence Capture

```bash
# Run incident triage (includes evidence capture)
incident_triage.sh --output-dir ./incident-$(date +%Y%m%d-%H%M%S)

# Quick triage without full cluster dump (faster)
incident_triage.sh --skip-dump --namespace production
```

### Manual Evidence Capture (Fallback)

If the triage script is unavailable, capture evidence manually:

```bash
# Create evidence directory
INCIDENT_DIR="./incident-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$INCIDENT_DIR"

# Capture cluster state
kubectl cluster-info dump --all-namespaces --output-directory="$INCIDENT_DIR/cluster-dump"

# Capture specific resources
kubectl get nodes -o wide > "$INCIDENT_DIR/nodes.txt"
kubectl get nodes -o json > "$INCIDENT_DIR/nodes.json"
kubectl get pods --all-namespaces -o wide > "$INCIDENT_DIR/pods.txt"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' > "$INCIDENT_DIR/events.txt"

# Capture logs for failing pods
kubectl get pods --all-namespaces --field-selector status.phase!=Running -o json > "$INCIDENT_DIR/failing-pods.json"
# For each failing pod, save logs (see below)
```

### What to Capture

**Always capture**:
- Node status and conditions
- Pod status across all relevant namespaces
- Recent events (especially warnings)
- Control plane health checks

**For specific issues**:
- **Crashing pods**: Current and previous logs, exit codes
- **Network issues**: DNS tests, endpoint status, network policies
- **Storage issues**: PVC/PV status, CSI driver logs
- **Control plane issues**: Component logs, etcd status

### Evidence Capture Timing

- **Before remediation**: Always capture state before making changes
- **After remediation**: Capture state after fix to verify resolution
- **Continuous**: Set up persistent log aggregation (Loki, Elasticsearch) for historical analysis

## Investigation Workflows by Symptom

### Workflow 1: Pods Pending

**Primary Script**: `pod_diagnostics.sh <POD_NAME> <NAMESPACE>`

**Investigation Steps**:

1. Check pod scheduling status:
   ```bash
   kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 10 "Events:"
   ```

2. Check node capacity:
   ```bash
   kubectl describe nodes | grep -A 5 "Allocated resources"
   ```

3. Check for taints/tolerations mismatch:
   ```bash
   kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.tolerations}'
   ```

4. Check PVC binding (if applicable):
   ```bash
   kubectl get pvc -n <NAMESPACE>
   ```

**Common Causes**:
- Insufficient cluster resources (CPU/memory)
- Node taints without matching tolerations
- Pending PVC preventing pod scheduling
- Node selector/affinity not matching any nodes

**Remediation Options**:
- Add nodes to increase capacity
- Adjust resource requests
- Fix PVC provisioning issues
- Update tolerations or remove taints

### Workflow 2: Pods CrashLoopBackOff

**Primary Script**: `pod_diagnostics.sh <POD_NAME> <NAMESPACE> -l -p`

**Investigation Steps**:

1. Get current and previous logs:
   ```bash
   kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER>
   kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER> --previous
   ```

2. Check exit code and reason:
   ```bash
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].lastState.terminated}'
   ```

3. Check startup dependencies:
   ```bash
   kubectl get configmaps,secrets -n <NAMESPACE>
   kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 10 "Environment"
   ```

4. Check resource limits:
   ```bash
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources}'
   ```

**Common Causes**:
- Application bugs or exceptions
- Missing ConfigMaps or Secrets
- Insufficient memory (leading to OOM)
- Failed health probes
- Database or dependency unavailability

**Remediation Options**:
- Fix application code or configuration
- Create missing ConfigMaps/Secrets
- Increase resource limits
- Adjust or disable problematic probes temporarily
- Ensure dependencies are available

### Workflow 3: OOMKilled

**Primary Script**: `pod_diagnostics.sh <POD_NAME> <NAMESPACE>`

**Investigation Steps**:

1. Check memory limits and usage:
   ```bash
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources.limits.memory}'
   kubectl top pod <POD_NAME> -n <NAMESPACE> --containers
   ```

2. Check for memory leaks in logs:
   ```bash
   kubectl logs <POD_NAME> -n <NAMESPACE> --previous | grep -i "memory\|heap\|oom"
   ```

3. Check node memory pressure:
   ```bash
   kubectl describe node <NODE_NAME> | grep -A 5 "MemoryPressure"
   ```

**Common Causes**:
- Memory limits too low for actual application needs
- Application memory leaks
- Large in-memory caches or data structures
- Memory-intensive operations without backpressure

**Remediation Options**:
- Increase memory limits (short-term)
- Fix memory leaks in application code (long-term)
- Implement memory usage monitoring and alerts
- Add memory resource requests to ensure proper scheduling

### Workflow 4: Network/DNS Issues

**Primary Script**: `network_debug.sh <NAMESPACE>`

**Investigation Steps**:

1. Test DNS resolution:
   ```bash
   kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
     nslookup <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local
   ```

2. Check CoreDNS health:
   ```bash
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
   ```

3. Check service endpoints:
   ```bash
   kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE>
   kubectl get pods -n <NAMESPACE> -l <SERVICE_SELECTOR> --show-labels
   ```

4. Check network policies:
   ```bash
   kubectl get networkpolicies -n <NAMESPACE>
   kubectl describe networkpolicy <POLICY_NAME> -n <NAMESPACE>
   ```

**Common Causes**:
- CoreDNS pods not running or misconfigured
- Service selector not matching pod labels
- Network policies blocking traffic
- CNI issues affecting pod networking

**Remediation Options**:
- Restart CoreDNS pods if unhealthy
- Fix service selector or pod labels
- Update network policies to allow required traffic
- Check CNI pod status and logs

### Workflow 5: Storage/Mount Failures

**Primary Script**: `storage_check.sh <NAMESPACE>`

**Investigation Steps**:

1. Check PVC status:
   ```bash
   kubectl get pvc -n <NAMESPACE>
   kubectl describe pvc <PVC_NAME> -n <NAMESPACE>
   ```

2. Check StorageClass and provisioner:
   ```bash
   kubectl get storageclass
   kubectl get pods -n kube-system | grep csi
   ```

3. Check volume attachments:
   ```bash
   kubectl get volumeattachments
   kubectl describe volumeattachment <ATTACHMENT_NAME>
   ```

4. Check CSI driver logs:
   ```bash
   kubectl logs -n kube-system <CSI_CONTROLLER_POD> -c csi-provisioner
   ```

**Common Causes**:
- StorageClass not available or misconfigured
- CSI driver pods not running
- Volume attachment failures (cloud provider issues)
- Node volume limits reached

**Remediation Options**:
- Fix StorageClass configuration
- Restart CSI driver pods
- Detach orphaned volumes
- Increase node volume limits or distribute workloads

### Workflow 6: Node Issues

**Primary Script**: `cluster_health_check.sh`

**Investigation Steps**:

1. Check node conditions:
   ```bash
   kubectl get nodes
   kubectl describe node <NODE_NAME> | grep -A 10 "Conditions"
   ```

2. Check for resource pressure:
   ```bash
   kubectl describe node <NODE_NAME> | grep -i "pressure"
   ```

3. Check kubelet logs (requires node access):
   ```bash
   kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
     chroot /host journalctl -u kubelet -n 100
   ```

4. Check pods on affected node:
   ```bash
   kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<NODE_NAME>
   ```

**Common Causes**:
- Disk pressure (out of disk space)
- Memory pressure (insufficient memory)
- PID pressure (too many processes)
- Kubelet or container runtime issues
- CNI failures on the node

**Remediation Options**:
- Clean up disk space (logs, unused images)
- Add memory or adjust workload distribution
- Restart kubelet or container runtime
- Cordon and drain node for maintenance
- Replace node if hardware issues

## Control Plane Diagnostics

### Checking Control Plane Health

**Automated**: `incident_triage.sh` or `cluster_health_check.sh`

**Manual**:

```bash
# Check readiness (verbose)
kubectl get --raw '/readyz?verbose'

# Check health
kubectl get --raw /healthz

# Check liveness
kubectl get --raw /livez

# Check control plane pods
kubectl get pods -n kube-system -l tier=control-plane

# Check component status (deprecated in newer versions)
kubectl get componentstatuses
```

### Control Plane Component Issues

**API Server**:
- Check logs: `kubectl logs -n kube-system <API_SERVER_POD>`
- Check load: High request rates, authentication issues
- Check connectivity: Network policies, firewalls

**etcd**:
- Check health: `kubectl exec -n kube-system <ETCD_POD> -- etcdctl endpoint health`
- Check disk I/O: Slow disk can cause cluster-wide issues
- Check backup status: Ensure regular backups

**Controller Manager**:
- Check logs: `kubectl logs -n kube-system <CONTROLLER_MANAGER_POD>`
- Check leader election: Only one should be leader

**Scheduler**:
- Check logs: `kubectl logs -n kube-system <SCHEDULER_POD>`
- Check pending pods: High count indicates scheduling issues

## Stabilization Techniques

**Warning**: These are remediation actions that modify cluster state. Always capture evidence first.

### Immediate Stabilization

**Scale down failing deployment**:
```bash
kubectl scale deployment <DEPLOYMENT> -n <NAMESPACE> --replicas=0
```

**Rollback to previous version**:
```bash
kubectl rollout undo deployment/<DEPLOYMENT> -n <NAMESPACE>
```

**Delete stuck pod**:
```bash
kubectl delete pod <POD_NAME> -n <NAMESPACE> --force --grace-period=0
```

**Cordon node to prevent new scheduling**:
```bash
kubectl cordon <NODE_NAME>
```

**Drain node to move workloads**:
```bash
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data
```

### Progressive Stabilization

1. **Isolate**: Cordon affected nodes or scale down affected workloads
2. **Restore service**: Scale up healthy replicas or rollback to known-good version
3. **Investigate**: Use diagnostic scripts to find root cause
4. **Fix**: Apply proper fix and test
5. **Resume**: Uncordon nodes and restore normal operations

## Common Incident Patterns

### Pattern 1: Deployment Gone Wrong

**Symptoms**: Multiple pods CrashLoopBackOff after recent deployment

**Response**:
1. Immediate rollback: `kubectl rollout undo deployment/<DEPLOYMENT> -n <NAMESPACE>`
2. Capture evidence: Logs from failing pods
3. Investigate: What changed between versions?
4. Fix and redeploy: With proper testing

### Pattern 2: Resource Exhaustion

**Symptoms**: Pods Pending, nodes under pressure

**Response**:
1. Check cluster capacity: `kubectl describe nodes | grep -A 5 "Allocated resources"`
2. Scale down non-critical workloads temporarily
3. Add nodes if capacity is the issue
4. Optimize resource requests/limits

### Pattern 3: Control Plane Degradation

**Symptoms**: Slow API responses, timeout errors

**Response**:
1. Check control plane components: `cluster_health_check.sh`
2. Check etcd health and disk I/O
3. Reduce API load if possible (stop operators, limit requests)
4. Check for certificate expiration
5. Consider control plane restart (last resort)

### Pattern 4: DNS Failures

**Symptoms**: Services unreachable, DNS resolution errors

**Response**:
1. Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
2. Check CoreDNS logs for errors
3. Restart CoreDNS if needed: `kubectl rollout restart deployment/coredns -n kube-system`
4. Test resolution: Use netshoot container to test DNS

### Pattern 5: Storage Provisioning Issues

**Symptoms**: PVCs stuck in Pending, FailedMount events

**Response**:
1. Check CSI driver: `storage_check.sh <NAMESPACE>`
2. Check cloud provider quotas (volume limits, IOPS limits)
3. Check StorageClass configuration
4. Restart CSI driver pods if unhealthy

## Post-Incident Review

After resolving the incident:

1. **Document timeline**: What happened, when, and how it was resolved
2. **Root cause analysis**: Why did it happen? What were contributing factors?
3. **Preventive measures**: How can we prevent this in the future?
4. **Monitoring improvements**: What alerts or monitoring would have caught this earlier?
5. **Process improvements**: What worked well? What could be improved in our response?

## Diagnostic Scripts Quick Reference

| Script | Use Case | Example |
|--------|----------|---------|
| `incident_triage.sh` | Initial incident assessment | `incident_triage.sh --namespace production` |
| `cluster_health_check.sh` | Quick cluster health baseline | `cluster_health_check.sh` |
| `cluster_assessment.sh` | Comprehensive cluster report | `cluster_assessment.sh -o report.md` |
| `pod_diagnostics.sh` | Pod-specific troubleshooting | `pod_diagnostics.sh my-pod default -l` |
| `network_debug.sh` | Network and DNS issues | `network_debug.sh production` |
| `storage_check.sh` | Storage and PVC problems | `storage_check.sh production` |
| `helm_release_debug.sh` | Helm deployment issues | `helm_release_debug.sh my-release default` |

All scripts are located in: `~/.claude/skills/k8s-troubleshooter/scripts/`

Run any script with `-h` or `--help` for detailed usage information.

## Additional Resources

- **SKILL.md**: Main skill documentation with detailed workflows
- **references/pod-troubleshooting.md**: Deep dive into pod lifecycle issues
- **references/service-networking.md**: Advanced networking troubleshooting
- **references/storage-csi.md**: Storage and CSI driver diagnostics
- **references/helm-debugging.md**: Helm-specific troubleshooting

## Emergency Contacts

Configure your organization's escalation procedures here:

- **On-call rotation**: [Link to PagerDuty/OpsGenie]
- **Infrastructure team**: [Contact information]
- **Platform team**: [Contact information]
- **Cloud provider support**: [Support portal links]

---

Remember: **Evidence first, action second.** Always preserve state before making changes.
