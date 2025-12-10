# Kubernetes Troubleshooter Skill

A comprehensive Claude skill for systematic Kubernetes troubleshooting and diagnostics.

## Overview

This skill provides expert-level Kubernetes troubleshooting workflows covering:
- Pod lifecycle and container issues
- Service connectivity and DNS
- Storage (PVC/PV) and CSI drivers
- Network policies and CNI (Calico)
- Helm charts and releases
- Node health and cluster-wide diagnostics

## Structure

```
k8s-troubleshooter/
├── SKILL.md              # Main skill definition with workflows
├── LICENSE.txt           # Apache 2.0 license
├── references/           # Deep-dive reference materials
│   ├── pod-troubleshooting.md
│   ├── service-networking.md
│   ├── storage-csi.md
│   ├── helm-debugging.md
│   ├── calico-cni.md
│   ├── incident-playbooks.md
│   └── mcp-integration.md
└── scripts/              # Diagnostic automation scripts
    ├── cluster_health_check.sh
    ├── pod_diagnostics.sh
    ├── network_debug.sh
    ├── storage_check.sh
    └── helm_release_debug.sh
```

## Quick Start

### Slash Commands

Trigger workflows using these patterns:
- `/pod-debug` - Pod issues (CrashLoopBackOff, OOMKilled, etc.)
- `/svc-debug` - Service connectivity and DNS
- `/storage-debug` - PVC/PV and storage issues
- `/network-debug` - Network policies and connectivity
- `/node-debug` - Node health and resource pressure
- `/helm-debug` - Helm deployment failures
- `/full-diag` - Comprehensive cluster health check

### Diagnostic Scripts

All scripts include usage help with `-h` flag:

```bash
# Cluster health check
./scripts/cluster_health_check.sh -v

# Pod diagnostics
./scripts/pod_diagnostics.sh my-pod default -l -v

# Network debugging
./scripts/network_debug.sh my-service default

# Storage check
./scripts/storage_check.sh my-pvc default

# Helm release debugging
./scripts/helm_release_debug.sh my-release default
```

## Features

### Production Safety
All diagnostic commands are **read-only by default**. Remediation commands require explicit user approval.

Safe commands:
- `kubectl get`, `describe`, `logs`, `top`
- `helm list`, `status`, `history`

### Progressive Disclosure
- Core workflows in SKILL.md (503 lines)
- Detailed references loaded only when needed
- Scripts for automated diagnostics

### Symptom-Based Entry Points
Organized by what you observe:
- Pod not starting → Pod Lifecycle workflow
- Service unreachable → Service Connectivity workflow
- PVC pending → Storage Diagnostics workflow
- Node NotReady → Node Health workflow

### Phased Triage
Each workflow follows structured phases:
1. **Baseline** - Current state assessment
2. **Inspect** - Component deep dive
3. **Correlate** - Dependencies and relationships
4. **Deep Dive** - Advanced diagnostics with references

## Reference Files

Comprehensive deep-dive guides:

- **pod-troubleshooting.md** (523 lines) - Container states, exit codes, probes, resources
- **service-networking.md** (583 lines) - DNS, endpoints, network policies, ingress
- **storage-csi.md** (642 lines) - PV/PVC, StorageClasses, CSI drivers, cloud providers
- **helm-debugging.md** (618 lines) - Release management, rollbacks, hooks
- **calico-cni.md** (612 lines) - CNI health, IPAM, BGP, network policies
- **incident-playbooks.md** (756 lines) - Step-by-step guides for common failures
- **mcp-integration.md** (276 lines) - MCP server setup for kubectl access

## Incident Response Playbooks

Real-world scenarios with diagnosis and resolution steps:
- CrashLoopBackOff
- OOMKilled
- DNS Resolution Failures
- ImagePullBackOff
- Node NotReady
- Pending Pods
- Stuck Terminating
- Service Unreachable
- PVC Pending
- Node Disk Pressure

## MCP Integration

Supports Model Context Protocol servers for automated kubectl access with:
- Read-only access patterns
- RBAC configuration examples
- Service account management
- Security and token hygiene

## Cloud Provider Support

Includes troubleshooting guidance for:
- AWS EKS (EBS CSI, ALB, NLB)
- Azure AKS (Azure Disk, Azure Files)
- Google GKE (GCE Persistent Disk)
- Generic Kubernetes patterns

## Development Status

**Implementation Status: 49/53 tasks completed (92%)**

Completed:
- ✅ Skill structure and core workflows (11 tasks)
- ✅ All reference files with TOCs (8 tasks)
- ✅ Diagnostic scripts - syntax validated, tested on 3 clusters (6 tasks)
- ✅ Validation and structural checks (6 tasks)
- ✅ Functional testing - tested on kind + 2 k0rdent clusters (6/7 tasks)
- ✅ Integration testing - validated on production clusters (5/6 tasks)
- ✅ Documentation review and cross-reference validation (2 tasks)

Tested On:
- ✅ **kind** cluster (local, 1 node)
- ✅ **k0rdent management** cluster (k0s, 2 nodes, 63 pods)
- ✅ **k0rdent regional** cluster (Azure CAPI, 4 nodes, 63 pods, active deployment)

Real Issues Found:
- ✅ CrashLoopBackOff (exit code 1)
- ✅ OOMKilled scenarios (high restart counts)
- ✅ Deployment race conditions (secret timing)
- ✅ Istio probe failures during startup
- ✅ 212-325 warning events during deployment

Pending (4 tasks):
- ⏳ Helm deployment failure testing (1 task)
- ⏳ MCP server integration testing (1 task)
- ⏳ Skill packaging and archival (2 tasks)

## Usage with Claude Code

This skill is designed for use with Claude Code CLI. It will be automatically activated when you ask Kubernetes troubleshooting questions.

Example prompts:
- "My pod is in CrashLoopBackOff, help me debug it"
- "Service DNS isn't resolving, what should I check?"
- "PVC is stuck in Pending state"
- "Run a full cluster health check"

## Contributing

This skill synthesizes knowledge from:
- Official Kubernetes debugging documentation
- Existing Claude Code K8s plugins (wshobson/agents, devops-claude)
- Real-world troubleshooting scenarios
- CNCF best practices
- Cloud provider documentation

## License

Apache License 2.0 - See LICENSE.txt
