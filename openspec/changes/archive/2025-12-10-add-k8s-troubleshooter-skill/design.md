# Design: Kubernetes Troubleshooter Claude Skill

## Context

Kubernetes troubleshooting requires systematic investigation across multiple domains (pods, services, networking, storage, nodes) with careful attention to production safety. This skill must encode expert knowledge while remaining adaptable to various cluster configurations and cloud providers.

**Stakeholders**: DevOps engineers, SREs, platform engineers, developers debugging their applications
**Constraints**: Must be production-safe (read-only by default), work across cloud providers, follow Claude Skill best practices

## Goals / Non-Goals

### Goals
- Provide systematic troubleshooting workflows for common Kubernetes issues
- Encode production-safe diagnostic patterns
- Support progressive disclosure to manage context efficiently
- Cover pod lifecycle, services, networking, storage, and cluster-level issues
- Include incident response playbooks for common failure modes
- Support Helm chart debugging
- Guide users to root causes, not just symptoms

### Non-Goals
- Automated remediation (this skill diagnoses; user decides on fixes)
- Cluster provisioning or management
- CI/CD pipeline configuration
- Application-level debugging (beyond K8s resource issues)
- Real-time monitoring setup

## Decisions

### 1. Skill Structure: Workflow-Based with Domain References

**Decision**: Use workflow-based structure in SKILL.md with domain-specific reference files

**Rationale**:
- Troubleshooting is inherently sequential (gather symptoms → hypothesize → investigate → confirm)
- Different issues require different domain knowledge (networking vs storage vs pod lifecycle)
- Progressive disclosure keeps SKILL.md lean while providing depth when needed

**Structure (source-aligned)**:
```
k8s-troubleshooter/
├── SKILL.md (symptom-first workflows + decision trees; frontmatter patterned after wshobson/agents + devops-claude k8s-troubleshooter)
├── scripts/
│   ├── cluster_health_check.sh  # portable baseline + cloud-aware hooks
│   ├── pod_diagnostics.sh       # crash/oom/image/pending triage
│   ├── network_debug.sh         # DNS/endpoints/policy/CNI checks
│   ├── storage_check.sh         # PVC/CSI/attach/mount checks
│   └── helm_release_debug.sh    # template/lint/dry-run/release status
└── references/
    ├── pod-troubleshooting.md   # states, events/logs correlation, readiness probes
    ├── service-networking.md    # endpoints, DNS, network policies, ingress basics
    ├── storage-csi.md           # PV/PVC, StorageClass, CSI controller/node health, cloud notes
    ├── helm-debugging.md        # lint/template/dry-run, stuck releases, secret/state cleanup
    ├── calico-cni.md            # Calico health, IPAM, policy debugging, BGP peering
    ├── incident-playbooks.md    # CrashLoop, OOM, DNS, node pressure, etc.
    └── mcp-integration.md       # kubectl MCP server setup/usage patterns (read-only first)
```

### 2. Production Safety: Read-Only by Default

**Decision**: All scripts and commands are read-only unless explicitly marked as "remediation"

**Rationale**:
- Production incidents should not be made worse by diagnostic tools
- Users must explicitly opt into any state-changing operations
- Matches established patterns from claude-k8s-troubleshooter

**Implementation**:
- Scripts use `kubectl get`, `describe`, `logs`, `top`, `debug` (read-only)
- No `kubectl delete`, `scale`, `edit`, `apply` in diagnostic workflows
- Remediation suggestions clearly labeled and separated
- Slash-command style workflow triggers (/pod-debug, /svc-debug, /full-diag) for fast recall, mirroring claude-k8s-troubleshooter patterns

### 3. Diagnostic Flow: Symptom-Based Entry Points

**Decision**: Organize by symptom/problem rather than by resource type

**Rationale**:
- Users typically know what's wrong ("pod won't start") not where to look
- Symptom-based approach matches how troubleshooting actually works
- Aligns with source materials (real-world scenarios, incident playbooks)

**Entry Points (symptom-first, phased: baseline → inspect → correlate → deep dive)**:
1. Pod not starting (Pending, CrashLoopBackOff, ImagePullBackOff, ErrImagePull)
2. Pod crashing (OOMKilled, exit codes, liveness/readiness failures)
3. Service unreachable (DNS, endpoints, selectors, network policies, ingress)
4. Storage issues (PVC pending, mount/attach failures, CSI errors)
5. Node problems (NotReady, pressure conditions, kubelet/container runtime health, CNI)
6. Cluster-wide issues (API server, control plane components, etcd symptoms via apiserver health, authentication/authorization errors)
7. Helm deployment failures (render errors, pending-upgrade, secret/state drift)
8. Connectivity path issues (pod↔pod, pod↔service, service↔ingress/LB) with policy simulation

### 4. Reference File Organization

**Decision**: One reference file per troubleshooting domain with table of contents

**Rationale**:
- Keeps individual files focused and navigable
- Claude loads only relevant domain when investigating
- Large files (>100 lines) include TOC per skill-creator guidelines

**Reference Files** (source mapping):
| File | Purpose | Key Content | Source inspirations |
|------|---------|-------------|---------------------|
| pod-troubleshooting.md | Pod lifecycle issues | States, events/logs correlation, probes, images, resources | K8s official debug docs, wshobson/agents pod workflows |
| service-networking.md | Service and ingress | DNS (CoreDNS), endpoints, selectors, network policies, ingress checks | devops-claude k8s-troubleshooter, Calico docs |
| storage-csi.md | PV/PVC and CSI | StorageClasses, mount/attach errors, controller/node components, cloud provider notes | CSI docs, EKS/AKS/GKE docs, Portworx guides |
| helm-debugging.md | Helm operations | lint, template, dry-run, stuck releases, secret/state cleanup | Helm docs, Helm failure blogs |
| calico-cni.md | CNI troubleshooting | calico-node health, IPAM, BGP, policy debug, readiness issues | Calico docs |
| incident-playbooks.md | Common failures | CrashLoop, OOM, DNS, node pressure, pending upgrades | Scenario collections, claude-k8s-troubleshooter |
| mcp-integration.md | MCP usage | kubectl MCP server setup, read-only scopes, token hygiene | MCP server collection |

### 5. Script Design: Composable Diagnostic Functions

**Decision**: Scripts are composable functions, not monolithic tools

**Rationale**:
- Different issues need different combinations of checks
- Claude can call specific functions as needed
- Easier to test and maintain

**Example**:
```bash
# cluster_health_check.sh
check_node_status() { ... }
check_system_pods() { ... }
check_resource_pressure() { ... }
check_api_server_health() { ... }
```

## Risks / Trade-offs

### Risk: Context Window Bloat
**Mitigation**:
- SKILL.md under 500 lines (per guidelines)
- Reference files loaded only when needed
- Scripts executed without loading into context when possible

### Risk: Cloud Provider Variations
**Mitigation**:
- Core workflows use portable kubectl commands
- Cloud-specific details (EBS/EFS, Azure Disk, GCE PD) in storage reference
- Document provider detection patterns

### Risk: Outdated Information
**Mitigation**:
- Focus on stable kubectl APIs
- Reference canonical Kubernetes docs
- Include version-specific notes where APIs differ

### Trade-off: Depth vs Breadth
**Choice**: Breadth with depth available via references
**Rationale**: More value in covering many scenarios with good-enough guidance than perfect guidance for few scenarios

## Open Questions

1. **MCP Server Integration**: Should the skill include guidance for setting up MCP servers for direct cluster access, or keep as external reference?
   - **Recommendation**: Include brief setup guidance in references, link to external MCP server repos

2. **Cloud Provider Scope**: How deeply should we cover EKS/AKS/GKE-specific issues vs generic Kubernetes?
   - **Recommendation**: Generic Kubernetes in SKILL.md, cloud-specific in storage-csi.md reference

3. **Namespace Conventions**: Should scripts default to specific namespace or always require explicit specification?
   - **Recommendation**: Always explicit (`-n $NAMESPACE` or `--all-namespaces` with user confirmation)
