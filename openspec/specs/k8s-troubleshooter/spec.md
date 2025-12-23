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

#### Scenario: Verbose readiness endpoint

- **WHEN** skill checks API server health
- **THEN** it MUST use `/readyz?verbose` for human-readable component status
- **AND** MAY fall back to `/healthz` for basic health only

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

The skill SHALL provide executable scripts for common diagnostic operations that can be run directly without modification. **Scripts SHALL be the recommended first choice before manual command workflows.** **Scripts SHALL be portable across macOS and Linux without requiring additional dependencies.**

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

#### Scenario: Scripts portable across macOS and Linux
- **WHEN** scripts are executed
- **THEN** scripts MUST run successfully on both macOS (BSD userland) and Linux (GNU userland)
- **AND** scripts MUST NOT require installation of additional tools (e.g., GNU coreutils via Homebrew)
- **AND** scripts MUST avoid non-portable constructs: `sed -i` without OS detection, `grep -P`, bash 4+ only features

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

#### Scenario: Incident triage as entry point

- **WHEN** user reports production incident
- **THEN** skill MUST recommend `incident_triage.sh` before domain-specific scripts
- **AND** domain-specific scripts (pod_diagnostics, network_debug, etc.) MUST be positioned as "deep dive" after triage

### Requirement: Incident Triage Workflow

The skill SHALL provide a structured incident triage workflow that captures evidence, assesses blast radius, and classifies symptoms before deep-dive investigation.

#### Scenario: Evidence capture on incident start

- **WHEN** user reports a production incident or requests incident triage
- **THEN** the skill MUST recommend capturing evidence first:
  - `kubectl cluster-info dump` (optional, can be skipped for speed)
  - Current node and pod status across all namespaces
  - Warning events cluster-wide
- **AND** evidence MUST be preserved in timestamped output directory

#### Scenario: Control plane health assessment

- **WHEN** triage workflow assesses control plane
- **THEN** it MUST query `/readyz?verbose` endpoint
- **AND** parse response to identify specific failing components
- **AND** output human-readable "healthy/degraded" status with failing component names

#### Scenario: Blast radius assessment

- **WHEN** triage workflow assesses incident scope
- **THEN** it MUST classify blast radius as one of:
  - "single pod" (one pod affected)
  - "single namespace" (multiple pods in one namespace)
  - "multiple namespaces" (pods across namespaces but not all)
  - "cluster-wide" (all namespaces or node-level issues)
- **AND** classification MUST inform subsequent workflow recommendations

#### Scenario: Symptom-based classification

- **WHEN** triage workflow analyzes cluster state
- **THEN** it MUST detect and classify symptoms:
  - Pending pods -> scheduling/capacity/taints/quotas/PVC binding
  - CrashLoopBackOff/OOMKilled -> logs/config/dependencies/resource limits
  - Service unreachable/DNS failures -> networking workflow
  - ContainerCreating/FailedMount -> storage workflow
  - Helm release stuck -> Helm workflow
- **AND** MUST output top symptoms with counts

#### Scenario: Triage report generation

- **WHEN** triage workflow completes analysis
- **THEN** it MUST generate structured report containing:
  - Blast radius classification
  - Control plane status
  - Top symptoms with affected resources
  - Recommended next workflows with specific commands
- **AND** report MUST be suitable for both terminal display and markdown file output

#### Scenario: Incident triage script invocation

- **WHEN** user needs production incident response
- **THEN** `incident_triage.sh` script MUST be available
- **AND** script MUST support options:
  - `--output-dir DIR`: Evidence capture location
  - `--namespace NS`: Scope to specific namespace
  - `--skip-dump`: Skip full cluster dump for faster triage
- **AND** script invocation MUST be documented as primary entry point for incidents

### Requirement: Incident Response Reference Documentation

The skill SHALL provide reference documentation for incident response procedures.

#### Scenario: Decision tree documentation

- **WHEN** user needs incident response guidance
- **THEN** reference documentation MUST include text-based decision tree:
  - Start: Can kubectl talk to API server?
  - Branch: Capture evidence
  - Branch: System-wide vs workload-level
  - Leaf nodes: Specific diagnostic workflows

#### Scenario: First five minutes checklist

- **WHEN** user starts incident response
- **THEN** reference documentation MUST include "first 5 minutes" checklist:
  - Confirm blast radius
  - Prefer read-only commands first
  - Capture cluster snapshot
  - Check control plane health
  - Classify by symptom

#### Scenario: Evidence preservation guidance

- **WHEN** documenting incident response
- **THEN** reference MUST explain:
  - Why evidence capture before remediation
  - What `cluster-info dump` captures
  - How to store evidence securely
  - Retention recommendations

### Requirement: Standardized Report Generation

The skill SHALL provide a standardized report template and methodology for generating consistent, auditable, actionable triage reports.

#### Scenario: Six-section report structure

- **WHEN** agent generates an investigation report
- **THEN** report MUST follow the six-section structure:
  - Section 0: Executive Triage Card
  - Section 1: Problem Statement
  - Section 2: Assessment & Findings
  - Section 3: Root Cause Analysis
  - Section 4: Remediation Plan
  - Section 5: Proof of Work
  - Section 6: Supporting Evidence

#### Scenario: Executive Triage Card front-loaded

- **WHEN** report is generated
- **THEN** Section 0 (Executive Triage Card) MUST be complete and actionable within 30-60 seconds of reading
- **AND** MUST include: Status, Severity, Impact, Primary Hypothesis with confidence, Top 3 Actions, Escalation Triggers
- **AND** MUST include "Most Dangerous Assumption" field

#### Scenario: Fact vs inference separation

- **WHEN** agent documents findings in Section 2
- **THEN** findings MUST be explicitly separated into:
  - "Observed Facts" (direct observations, verifiable)
  - "Derived Inferences" (interpretations, labeled with confidence)
- **AND** each inference MUST reference which facts it is based on

#### Scenario: Hypothesis ranking with falsification tests

- **WHEN** agent performs root cause analysis in Section 3
- **THEN** hypotheses MUST be ranked (H1 most likely, H2, H3)
- **AND** each hypothesis MUST include:
  - Evidence supporting it
  - Evidence against it or gaps
  - A falsification test (what would disprove it quickly)
  - Confidence level (High/Medium/Low)

#### Scenario: Alternative hypotheses documented

- **WHEN** agent completes Executive Triage Card
- **THEN** card MUST include 1-3 alternative hypotheses considered
- **AND** each alternative MUST explain why it is less likely than primary

#### Scenario: Proof of work documentation

- **WHEN** agent generates Section 5
- **THEN** report MUST document:
  - All inputs consulted (with timestamps)
  - All commands executed (exact commands)
  - Constraints encountered (permissions, missing data)

#### Scenario: Remediation plan with validation

- **WHEN** agent provides remediation steps in Section 4
- **THEN** each step MUST include:
  - The specific action
  - How to validate success
  - How to rollback if needed

#### Scenario: Severity classification guidance

- **WHEN** agent assigns severity
- **THEN** skill MUST provide severity guidelines:
  - P1: Production down, all users affected, revenue impact
  - P2: Major feature degraded, significant user impact
  - P3: Minor feature affected, workaround available
  - P4: Low impact, cosmetic, monitoring-only

#### Scenario: Blast radius classification

- **WHEN** agent assesses blast radius
- **THEN** skill MUST use categories:
  - Single Pod: One pod affected, service functional
  - Namespace: Multiple pods in namespace
  - Multi-Namespace: Multiple namespaces impacted
  - Cluster-Wide: Control plane or cluster-level resources

### Requirement: Severity-Based Report Depth

The skill SHALL provide guidance for calibrating report depth based on incident severity.

#### Scenario: P1/P2 incident reporting
- **WHEN** investigating a P1 or P2 severity incident
- **THEN** all 6 report sections are fully populated
- **AND** multiple ranked hypotheses are provided with falsification tests
- **AND** complete evidence chains with timestamps are included
- **AND** full remediation plans with rollback procedures are documented

#### Scenario: P3 incident reporting
- **WHEN** investigating a P3 severity incident
- **THEN** the Executive Card is fully populated
- **AND** other sections use concise format
- **AND** only the primary hypothesis is documented
- **AND** evidence is abbreviated to key findings only
- **AND** remediation focuses on the direct fix without alternatives

#### Scenario: P4 incident reporting
- **WHEN** investigating a P4 severity incident
- **THEN** the Executive Card uses abbreviated format
- **AND** remaining content is a single summary paragraph
- **AND** Supporting Evidence section may be omitted entirely

