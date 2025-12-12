# k8s-troubleshooter Specification

## Purpose
TBD - created by archiving change add-k8s-troubleshooter-skill. Update Purpose after archive.
## Requirements
### Requirement: Skill Metadata and Triggering

The skill SHALL provide YAML frontmatter with `name` and `description` fields that accurately describe when to use the skill for Kubernetes troubleshooting tasks.

#### Scenario: Skill triggers on troubleshooting request
- **WHEN** user asks "why is my pod not starting" or "debug my kubernetes deployment"
- **THEN** the skill MUST be triggered based on frontmatter description matching

#### Scenario: Skill provides comprehensive description
- **WHEN** skill metadata is loaded
- **THEN** description MUST include troubleshooting contexts: pods, services, networking, storage, helm, cluster health

#### Scenario: Slash-command style entry points
- **WHEN** user invokes slash-style prompts (e.g., `/pod-debug`, `/svc-debug`, `/full-diag`)
- **THEN** skill MUST route to the appropriate troubleshooting workflow

---

### Requirement: Systematic Diagnostic Workflow

The skill SHALL provide systematic troubleshooting workflows that guide users from symptoms to root causes through structured investigation steps.

#### Scenario: Pod failure investigation
- **WHEN** user reports pod not starting
- **THEN** skill MUST guide through: check pod status, examine events, review container logs, inspect resource requests, verify image availability

#### Scenario: Service connectivity investigation
- **WHEN** user reports service unreachable
- **THEN** skill MUST guide through: verify service exists, check endpoints, validate selectors, test DNS resolution, examine network policies

#### Scenario: Storage issue investigation
- **WHEN** user reports PVC pending or mount failures
- **THEN** skill MUST guide through: check PVC status, examine events, verify StorageClass, inspect CSI driver health, review node permissions

#### Scenario: Baseline-first triage
- **WHEN** any troubleshooting workflow starts
- **THEN** skill MUST begin with lightweight, read-only baseline checks (namespaces, node status, events, recent changes) before deep dives

#### Scenario: Logs/events correlation
- **WHEN** collecting evidence
- **THEN** skill MUST guide correlating pod logs with Kubernetes events in time order to surface causal signals

---

### Requirement: Production-Safe Command Patterns

The skill SHALL provide kubectl commands that are read-only by default and clearly separate diagnostic commands from remediation actions.

#### Scenario: Diagnostic commands are read-only
- **WHEN** skill suggests kubectl commands for diagnosis
- **THEN** commands MUST use read-only operations: get, describe, logs, top, debug (ephemeral containers), events

#### Scenario: Remediation actions are explicit
- **WHEN** skill suggests state-changing operations
- **THEN** commands MUST be clearly labeled as "Remediation" and require explicit user confirmation

#### Scenario: Namespace handling is explicit
- **WHEN** skill generates kubectl commands
- **THEN** commands MUST include explicit namespace flag (-n) or --all-namespaces with appropriate context

#### Scenario: Read-only defaults from source-aligned patterns
- **WHEN** suggesting commands derived from reference sources
- **THEN** commands MUST mirror read-only guardrails (get/describe/logs/top/debug) and avoid mutating operations unless explicitly labeled as remediation

---

### Requirement: Incident Response Playbooks

The skill SHALL provide structured playbooks for common Kubernetes failure scenarios with step-by-step diagnostic and resolution guidance.

#### Scenario: CrashLoopBackOff playbook
- **WHEN** user reports CrashLoopBackOff
- **THEN** skill MUST provide: exit code analysis, log inspection, liveness probe review, resource limit check, dependency verification

#### Scenario: OOMKilled playbook
- **WHEN** user reports OOMKilled containers
- **THEN** skill MUST provide: memory limit analysis, actual usage inspection, memory leak indicators, right-sizing recommendations

#### Scenario: DNS resolution failure playbook
- **WHEN** user reports DNS issues in cluster
- **THEN** skill MUST provide: CoreDNS pod health, service resolution test, network policy review, upstream DNS verification

#### Scenario: Node NotReady playbook
- **WHEN** user reports nodes in NotReady state
- **THEN** skill MUST provide: kubelet status, system resource pressure, container runtime health, network connectivity checks

#### Scenario: Helm release stuck/pending
- **WHEN** user reports Helm release stuck in pending-upgrade or failed state
- **THEN** skill MUST provide: helm status/history, lint/template/dry-run guidance, secret/state inspection, safe rollback/cleanup guidance

---

### Requirement: Progressive Disclosure Reference Structure

The skill SHALL organize detailed domain knowledge in reference files that are loaded only when needed, keeping SKILL.md lean.

#### Scenario: SKILL.md under size limit
- **WHEN** SKILL.md is measured
- **THEN** file MUST be under 500 lines

#### Scenario: Reference files have table of contents
- **WHEN** reference file exceeds 100 lines
- **THEN** file MUST include table of contents at top

#### Scenario: Domain-specific references
- **WHEN** user needs deep dive into specific domain
- **THEN** appropriate reference file MUST be available: pod-troubleshooting.md, service-networking.md, storage-csi.md, helm-debugging.md, calico-cni.md, incident-playbooks.md

#### Scenario: MCP integration reference
- **WHEN** user needs in-chat cluster access
- **THEN** reference MUST describe MCP server setup and read-only usage patterns for kubectl access

---

### Requirement: Diagnostic Scripts

The skill SHALL provide executable scripts for common diagnostic operations that can be run directly without modification. **Scripts SHALL be the recommended first choice before manual command workflows.**

#### Scenario: Cluster health check script
- **WHEN** user needs cluster overview
- **THEN** script MUST check: node status, system pod health, resource pressure, API server responsiveness
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Pod diagnostics script
- **WHEN** user needs detailed pod analysis
- **THEN** script MUST collect: pod status, events, container logs, resource usage, restart history
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Network debugging script
- **WHEN** user needs network troubleshooting
- **THEN** script MUST test: DNS resolution, service endpoints, network policy effects, pod-to-pod connectivity
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Scripts are composable
- **WHEN** scripts are designed
- **THEN** scripts MUST use functions that can be called individually or composed for specific investigations

#### Scenario: Helm release debugging script
- **WHEN** user needs Helm troubleshooting
- **THEN** script MUST cover: helm lint/template/dry-run, release status/history, pending-upgrade detection, safe cleanup guidance
- **AND** script invocation MUST be presented before manual commands

#### Scenario: Cluster assessment script
- **WHEN** user needs comprehensive cluster assessment report
- **THEN** script `cluster_assessment.sh` MUST be invoked as the primary method
- **AND** manual assessment phases MUST be labeled as fallback only

### Requirement: Helm Chart Debugging

The skill SHALL provide guidance for debugging Helm chart deployments, including template rendering issues and stuck releases.

#### Scenario: Helm template debugging
- **WHEN** user reports Helm deployment issues
- **THEN** skill MUST guide through: helm lint, helm template --debug, helm install --dry-run

#### Scenario: Stuck release recovery
- **WHEN** user reports Helm release stuck in pending-upgrade
- **THEN** skill MUST provide: release status inspection, secret examination, rollback options, force cleanup procedures

#### Scenario: Template/rendering validation
- **WHEN** user needs to verify chart output
- **THEN** skill MUST guide through `helm template --debug` and schema/values validation before apply

---

### Requirement: CNI and Network Policy Troubleshooting

The skill SHALL provide guidance for debugging Container Network Interface issues and network policy behavior.

#### Scenario: Calico CNI troubleshooting
- **WHEN** user reports Calico-related networking issues
- **THEN** skill MUST guide through: calico-node health, BGP peering status, IPAM verification, policy evaluation

#### Scenario: Network policy debugging
- **WHEN** user reports unexpected traffic blocking
- **THEN** skill MUST provide: policy listing, policy simulation, traffic flow analysis, default deny verification

---

### Requirement: CSI Storage Driver Troubleshooting

The skill SHALL provide guidance for debugging Container Storage Interface driver issues across cloud providers.

#### Scenario: CSI driver health check
- **WHEN** user reports storage attachment failures
- **THEN** skill MUST guide through: CSI driver pod health, controller/node component status, volume attachment events

#### Scenario: Cloud-specific storage debugging
- **WHEN** user uses cloud-managed Kubernetes (EKS, AKS, GKE)
- **THEN** skill MUST provide cloud-specific guidance: EBS/EFS CSI, Azure Disk/Files CSI, GCE PD CSI

#### Scenario: PVC/PV lifecycle tracing
- **WHEN** PVC is pending or mount fails
- **THEN** skill MUST trace PVC→PV→StorageClass→CSI path including events, attachment objects, and node suitability checks

---

### Requirement: Multi-Cloud and Environment Adaptability

The skill SHALL adapt guidance to different Kubernetes environments and cloud providers without requiring environment-specific skill variants.

#### Scenario: Environment detection guidance
- **WHEN** skill is used
- **THEN** skill MUST guide user to identify environment context before providing cloud-specific advice

#### Scenario: Portable core workflows
- **WHEN** skill provides diagnostic workflows
- **THEN** core workflows MUST use portable kubectl commands that work across all Kubernetes distributions

#### Scenario: Environment-specific overlays
- **WHEN** environment is identified (managed cloud vs on-prem)
- **THEN** skill MUST offer provider-specific overlays (storage, CNI, LB/DNS) without replacing the portable core workflow

### Requirement: Automation-First Behavior

The skill SHALL prioritize automation scripts over manual command sequences when scripts are available for the requested task.

#### Scenario: Script recommended before manual workflow
- **WHEN** a workflow has an associated automation script in `scripts/` directory
- **THEN** the skill documentation MUST present the script invocation command before any manual kubectl commands
- **AND** the script command MUST include full path and common parameters

#### Scenario: Automation-first section visible at top
- **WHEN** the skill is invoked
- **THEN** an "Automation First" section MUST appear within the first 100 lines of SKILL.md
- **AND** the section MUST include a table mapping tasks to their automation scripts

#### Scenario: Manual workflows labeled as fallback
- **WHEN** a workflow has both script and manual options
- **THEN** the manual workflow section MUST be explicitly labeled as "Fallback" or "For Understanding"
- **AND** the script option MUST be labeled as the primary/recommended approach

#### Scenario: Script invocation includes working examples
- **WHEN** documenting a script
- **THEN** the documentation MUST include at least one complete, copy-paste ready invocation example
- **AND** the example MUST use the full path relative to skill directory

---

