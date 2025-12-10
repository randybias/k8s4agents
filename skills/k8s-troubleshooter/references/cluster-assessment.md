# Cluster Assessment and Reporting

## Overview

The cluster assessment workflow provides a comprehensive, standardized approach to evaluating Kubernetes cluster health, capacity, security posture, and operational readiness. Unlike basic health checks that focus on immediate availability, this assessment generates a detailed report suitable for documentation, audits, and capacity planning.

## When to Use Cluster Assessment

### Use Cases
- **Initial Cluster Evaluation**: Baseline assessment of new or inherited clusters
- **Capacity Planning**: Understanding resource utilization and growth needs
- **Audit and Compliance**: Generating documentation for security reviews
- **Incident Post-Mortems**: Capturing cluster state during or after incidents
- **Quarterly Reviews**: Regular operational health checks
- **Handoff Documentation**: Transferring cluster ownership between teams

### Comparison to Basic Health Checks

| Feature | Health Check | Cluster Assessment |
|---------|-------------|-------------------|
| Speed | Fast (30s) | Comprehensive (2-5 min) |
| Output | Terminal | Markdown report |
| Scope | Critical issues | Full analysis |
| Recommendations | None | Prioritized |
| Storage | None | Persistent report |
| Use Case | Quick status | Documentation/Planning |

## Assessment Workflow

### Phase 1: Data Collection

The assessment gathers comprehensive cluster data across multiple dimensions:

**Control Plane:**
```bash
# API server health endpoints
kubectl get --raw /healthz
kubectl get --raw /readyz
kubectl get --raw /livez

# Control plane components
kubectl get pods -n kube-system
kubectl get componentstatuses  # If available
```

**Nodes:**
```bash
# Node status and conditions
kubectl get nodes -o wide
kubectl describe nodes

# Resource usage
kubectl top nodes

# Capacity and allocation
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Workloads:**
```bash
# Pod status across all namespaces
kubectl get pods --all-namespaces

# Workload controllers
kubectl get deployments,statefulsets,daemonsets --all-namespaces

# Resource consumption
kubectl top pods --all-namespaces
```

**Storage:**
```bash
# Storage classes and capabilities
kubectl get storageclass

# PVC/PV status
kubectl get pvc,pv --all-namespaces

# CSI drivers
kubectl get csidrivers
kubectl get pods -n kube-system | grep csi
```

**Networking:**
```bash
# CNI status
kubectl get pods -n kube-system | grep -E 'calico|flannel|weave|cilium'

# Services and endpoints
kubectl get svc,endpoints --all-namespaces

# Network policies
kubectl get networkpolicies --all-namespaces

# DNS health
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Events and Issues:**
```bash
# Recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Failed pods
kubectl get pods --all-namespaces --field-selector status.phase=Failed

# Warning events
kubectl get events --all-namespaces --field-selector type=Warning
```

### Phase 2: Analysis and Scoring

The assessment analyzes collected data to identify:

1. **Resource Overcommitment**
   - CPU/Memory limits vs. node capacity
   - Request ratios and actual usage
   - Overcommitment risk level

2. **Failure Indicators**
   - Failed pods and reasons
   - Pods with high restart counts
   - Pending pods and scheduling issues

3. **Resource Pressure**
   - Node conditions (MemoryPressure, DiskPressure, PIDPressure)
   - High utilization nodes (>80% CPU/Memory)
   - Storage capacity concerns

4. **Security Posture**
   - Authentication methods in use
   - Network policy coverage
   - Pod security standards
   - RBAC configuration

5. **Operational Health**
   - Control plane stability
   - DNS functionality
   - Monitoring stack availability
   - Backup/DR capabilities

### Phase 3: Report Generation

The assessment generates a structured markdown report with:

**Executive Summary:**
- Overall health score (0-100)
- Cluster identification
- Assessment timestamp
- Critical issues count

**Detailed Sections:**
1. Control Plane Health
2. Node Infrastructure
3. Resource Allocation
4. Workload Status
5. Storage Infrastructure
6. Network Configuration
7. Platform Components (if applicable)
8. Observability Stack
9. Security Posture
10. Recent Events
11. Prioritized Recommendations
12. Cluster Capabilities

**Recommendations are prioritized:**
- **High Priority**: Issues requiring immediate attention (security, capacity)
- **Medium Priority**: Operational improvements (monitoring, policies)
- **Low Priority**: Optimization and best practices

### Phase 4: Actionable Recommendations

Each recommendation includes:
- **Problem Statement**: What the issue is
- **Impact**: Why it matters
- **Action Items**: Specific steps to address
- **References**: Documentation links

Example:
```markdown
### High Priority
1. **Address Resource Overcommitment** ⚠️
   - **Problem**: Worker node has 850% CPU limits overcommitted
   - **Impact**: Risk of OOMKilled pods and performance degradation
   - **Actions**:
     - Review resource limits on k0s-worker-1 workloads
     - Consider adding worker nodes
     - Implement namespace resource quotas
   - **Reference**: https://kubernetes.io/docs/concepts/policy/resource-quotas/
```

## Using the Assessment Script

### Basic Usage

```bash
# Run assessment with default output
./scripts/cluster_assessment.sh

# Specify output file
./scripts/cluster_assessment.sh -o my-cluster-report.md

# Use specific kubeconfig
./scripts/cluster_assessment.sh -c ~/.kube/prod-config -o prod-cluster-report.md
```

### Script Options

```
Options:
  -o, --output FILE         Output markdown file (default: cluster-assessment-TIMESTAMP.md)
  -c, --kubeconfig FILE     Path to kubeconfig file
  -h, --help                Show this help message
```

### Output Location

By default, reports are generated in the current directory with timestamp:
- Format: `cluster-assessment-YYYYMMDD-HHMMSS.md`
- Example: `cluster-assessment-20251210-160245.md`

## Automating Regular Assessments

### Monthly Assessment

Create a cron job for regular cluster assessments:

```bash
# Monthly on the 1st at 2 AM
0 2 1 * * cd /path/to/assessments && /path/to/cluster_assessment.sh -o monthly-$(date +\%Y\%m).md
```

### Pre-Change Assessment

Run before major cluster changes:

```bash
# Before upgrade
./cluster_assessment.sh -o pre-upgrade-$(date +%Y%m%d).md

# Perform upgrade
...

# After upgrade
./cluster_assessment.sh -o post-upgrade-$(date +%Y%m%d).md

# Compare reports
diff -u pre-upgrade-*.md post-upgrade-*.md
```

### CI/CD Integration

Include in deployment pipelines:

```yaml
# GitLab CI example
cluster-assessment:
  stage: verify
  script:
    - kubectl config use-context $CLUSTER_NAME
    - ./scripts/cluster_assessment.sh -o reports/assessment-$CI_COMMIT_SHORT_SHA.md
  artifacts:
    paths:
      - reports/*.md
    expire_in: 90 days
```

## Interpreting Assessment Results

### Health Score Ranges

- **90-100**: Excellent - Production-ready with minor optimizations
- **75-89**: Good - Operational with recommended improvements
- **60-74**: Fair - Functional but needs attention
- **Below 60**: Poor - Critical issues requiring immediate action

### Common Issues and Solutions

**Resource Overcommitment (Score -10 per node)**
- Indicates risk of pod evictions
- Solution: Adjust resource limits or add capacity

**Failed Pods (Score -5 per failed pod)**
- Check pod logs: `kubectl logs <pod> --previous`
- Review events: `kubectl describe pod <pod>`

**Node Pressure (Score -15 per affected node)**
- MemoryPressure: Add RAM or reduce workload memory
- DiskPressure: Expand storage or clean up
- PIDPressure: Increase kernel.pid_max or reduce containers

**No Monitoring (Score -10)**
- Deploy metrics-server for basic monitoring
- Consider full stack (Prometheus/Grafana)

**Missing Network Policies (Score -5)**
- Creates security risk via unrestricted pod communication
- Implement zero-trust networking

## Assessment Report Template

The report follows this standard structure:

```markdown
# Kubernetes Cluster Assessment Report

## Executive Summary
- Cluster identification
- Overall health score
- Critical findings

## 1-12. Detailed Sections
[Comprehensive analysis of each cluster aspect]

## Recommendations
### High Priority
[Immediate action items]

### Medium Priority
[Operational improvements]

### Low Priority
[Optimizations and best practices]

## Conclusion
- Key strengths
- Areas for improvement
- Overall assessment
```

## Best Practices

### Before Assessment
1. Ensure kubectl access is configured
2. Verify metrics-server is running (for resource usage)
3. Have sufficient permissions (read-only cluster-wide access)
4. Note any ongoing incidents or maintenance

### During Assessment
1. Run during normal operations (not during peak load)
2. Allow 2-5 minutes for complete data collection
3. Don't interrupt the assessment process

### After Assessment
1. Review the report immediately for critical issues
2. Share with relevant team members
3. File issues for high-priority items
4. Archive report for future reference
5. Track recommendations to completion

### Report Management
1. Store reports in version control (git)
2. Use consistent naming conventions
3. Include cluster context in commit messages
4. Compare reports over time to track improvements

```bash
# Example git workflow
git add cluster-assessment-20251210.md
git commit -m "docs: monthly cluster assessment for production cluster"
git push origin main
```

## Advanced Assessment Topics

### Multi-Cluster Assessment

For organizations managing multiple clusters:

```bash
# Assess all clusters
for cluster in prod-us-east prod-us-west prod-eu-west; do
  kubectl config use-context $cluster
  ./cluster_assessment.sh -o reports/${cluster}-$(date +%Y%m).md
done

# Generate comparison report
./scripts/compare_clusters.sh reports/*-$(date +%Y%m).md > cluster-comparison.md
```

### Custom Assessment Criteria

Extend the assessment for organization-specific requirements:

1. **Compliance Checks**
   - PCI-DSS requirements
   - HIPAA controls
   - SOC 2 criteria

2. **Cost Analysis**
   - Resource waste identification
   - Right-sizing recommendations
   - Reserved capacity optimization

3. **Platform Standards**
   - Required labels present
   - Naming conventions followed
   - Backup configurations verified

### Integration with Alerting

Use assessment findings to configure alerts:

```yaml
# Prometheus alert based on assessment
- alert: ClusterAssessmentRecommended
  expr: time() - cluster_last_assessment_timestamp > 2592000  # 30 days
  annotations:
    summary: "Cluster assessment is overdue"
    description: "Last assessment was {{ $value | humanizeDuration }} ago"
```

## Troubleshooting

### Assessment Fails to Connect
```bash
# Verify kubectl access
kubectl cluster-info

# Check kubeconfig
kubectl config view
kubectl config current-context
```

### Incomplete Data Collection
```bash
# Check metrics-server
kubectl get deployment metrics-server -n kube-system

# Verify permissions
kubectl auth can-i get pods --all-namespaces
kubectl auth can-i get nodes
```

### Report Generation Errors
```bash
# Check required tools
command -v jq || echo "jq not installed"
command -v yq || echo "yq not installed"

# Verify write permissions
touch test-report.md && rm test-report.md
```

## Related Workflows

- **Basic Health Check** (`cluster_health_check.sh`): Quick status verification
- **Pod Diagnostics** (`pod_diagnostics.sh`): Deep dive into pod issues
- **Network Debug** (`network_debug.sh`): Network connectivity troubleshooting
- **Storage Check** (`storage_check.sh`): Storage infrastructure validation

## References

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/)
- [Production Readiness Checklist](https://kubernetes.io/docs/setup/best-practices/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Cluster Hardening](https://kubernetes.io/docs/concepts/security/hardening-guide/)
