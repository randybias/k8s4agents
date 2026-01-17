---
name: k8s-troubleshooter
version: "0.1.0"
description: |
  Use this skill when users report Kubernetes cluster issues, pod failures, or need incident response.
  Comprehensive troubleshooting for diagnosing cluster, workload, networking, storage, and Helm issues.
  Invoke for: pods not starting (Pending, CrashLoopBackOff, ImagePull), service connectivity problems,
  DNS resolution failures, storage/PVC issues, node health problems, CNI/Calico networking, Helm release
  failures, or cluster-wide performance degradation. Provides systematic diagnostic workflows, standardized
  investigation reports with severity-based depth (Executive Triage Cards for rapid decision-making),
  and incident response playbooks with phased triage (baseline → inspect → correlate → deep dive).
  All commands are read-only by default for production safety.
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

## Standardized Report Generation

After completing an investigation, generate a structured report that enables rapid decision-making, clear auditing, and trustworthy communication. This format separates verified facts from inferences, ranks hypotheses with falsification tests, and provides explicit proof-of-work documentation.

### Report Depth Guidelines

| Severity | Executive Card | Other Sections |
|----------|---------------|----------------|
| P1/P2 | Full detail | Full detail |
| P3 | Full detail | Concise (primary hypothesis only, abbreviated evidence) |
| P4 | Abbreviated | Minimal (summary only) |

For P3/P4 incidents:
- Low-confidence hypotheses can be 1-line bullets
- Supporting Evidence can reference earlier sections instead of repeating
- "What Changed" can be omitted if unknown

### Report Template Overview

Every investigation report should follow this 7-section structure:

| Section | Purpose | Time to Read |
|---------|---------|--------------|
| 0. Executive Triage Card | 30-60 second decision summary | 30 sec |
| 1. Problem Statement | What's broken and success criteria | 1 min |
| 2. Assessment & Findings | Facts, inferences, and scope | 2-3 min |
| 3. Root Cause Analysis | Ranked hypotheses with evidence | 2-3 min |
| 4. Remediation Plan | Actions, validation, rollback | 2 min |
| 5. Proof of Work | Commands executed, sources consulted | 1 min |
| 6. Supporting Evidence | Log excerpts, kubectl output | Reference |

### Report Template - MANDATORY STRUCTURE

**CRITICAL**: This is a **literal template**. Fill in the placeholders but DO NOT:
- Add, remove, or rename sections
- Add subsections beyond those shown
- Rearrange section order
- Create alternative formats

Copy this template and fill in the bracketed placeholders:

---BEGIN MANDATORY TEMPLATE---

# Kubernetes Incident Triage Report

## 0. Executive Triage Card

| Field | Value |
|-------|-------|
| **Status** | [Choose ONE: 🔴 Active Incident / 🟡 Degraded / 🟢 Resolved] |
| **Severity** | [P1/P2/P3/P4] |
| **Impact** | [Single Pod / Namespace / Multi-Namespace / Cluster-Wide] |
| **Duration** | Started: [timestamp], Ongoing: [duration] |

### Primary Hypothesis
[One clear sentence] — Confidence: [High/Medium/Low]

⚠️ **Most Dangerous Assumption**: [What assumption, if wrong, would invalidate this approach]

### Top 3 Recommended Actions

| Priority | Action | Expected Outcome | Risk |
|----------|--------|------------------|------|
| 1 | [Specific kubectl command or action] | [What this fixes] | [Low/Med/High] |
| 2 | [Specific kubectl command or action] | [What this fixes] | [Low/Med/High] |
| 3 | [Specific kubectl command or action] | [What this fixes] | [Low/Med/High] |

### Escalation Triggers
- [ ] Escalate if: [specific measurable condition]
- [ ] Escalate if: [specific measurable condition]

### Alternative Hypotheses Considered
1. [H2 name] — Confidence: [X%], Why deprioritized: [brief reason]
2. [H3 name] — Confidence: [X%], Why deprioritized: [brief reason]

## 1. Problem Statement

### Symptoms
- [Observable symptom 1]
- [Observable symptom 2]
- [Observable symptom 3]

### Timeline
- **First detected**: [timestamp, detection method]
- **Reported by**: [source: alert/user/automated]
- **Current duration**: [time since detection]

### Exit Criteria Checklist
- [ ] [Specific measurable outcome]
- [ ] [Specific measurable outcome]
- [ ] [Specific measurable outcome]

## 2. Assessment & Findings

### Classification

| Aspect | Value |
|--------|-------|
| **Category** | [Pod/Service/Storage/Node/Network/Helm/Cluster] |
| **Blast Radius** | [Single pod / Namespace / Multi-namespace / Cluster-wide] |
| **User Impact** | [None / Degraded / Partial outage / Full outage] |

### Scope

| Status | Resources |
|--------|-----------|
| **Confirmed Affected** | [list pods/services/nodes] |
| **Suspected Affected** | [list resources] |
| **Confirmed Unaffected** | [list key resources verified healthy] |

### Observed Facts
> Facts are directly verifiable from kubectl output, logs, or metrics.

- **[FACT-1]** [Description] — Source: `[kubectl command or log reference]`
- **[FACT-2]** [Description] — Source: `[kubectl command or log reference]`
- **[FACT-3]** [Description] — Source: `[kubectl command or log reference]`

### Derived Inferences
> Inferences are conclusions drawn from facts.

- **[INF-1]** [Inference statement] — Confidence: [High/Medium/Low]
  - Based on: FACT-1, FACT-2
  - Could be wrong if: [falsification condition]
- **[INF-2]** [Inference statement] — Confidence: [High/Medium/Low]
  - Based on: FACT-3
  - Could be wrong if: [falsification condition]

### What Changed

| When | What Changed | Who/What | Correlation |
|------|-------------|----------|-------------|
| [timestamp] | [change description] | [actor/system] | [likely/possible/unlikely] |

### Constraints Encountered
- [Access limitation, missing data, or tool constraint]
- [Additional constraint if applicable]

## 3. Root Cause Analysis

### H1: [Primary Hypothesis Name] — Confidence: [High/Medium/Low]

**Statement**: [Clear, specific hypothesis about root cause]

**Evidence For**:
- [Supporting evidence] (references FACT-n)
- [Supporting evidence] (references FACT-n)

**Evidence Against**:
- [Contradicting evidence or gaps]

**Falsification Test**:
- Command: `[specific kubectl command]`
- Expected if TRUE: [specific result]
- Expected if FALSE: [alternative result]

---

### H2: [Secondary Hypothesis Name] — Confidence: [Medium/Low]

**Statement**: [Alternative root cause]

**Evidence For**:
- [Supporting evidence]

**Evidence Against**:
- [Why less likely than H1]

**Falsification Test**:
- Command: `[specific command]`
- Expected if TRUE: [result]
- Expected if FALSE: [result]

---

### Remaining Unknowns
- [ ] [Unknown 1]: [Why this matters for the investigation]
- [ ] [Unknown 2]: [What additional access/data would resolve this]

## 4. Remediation Plan

### Immediate Mitigation

| Step | Action | Validation | Rollback |
|------|--------|------------|----------|
| 1 | [Specific action/command] | [How to verify success] | [How to undo] |
| 2 | [Specific action/command] | [How to verify success] | [How to undo] |

### Fix Forward

| Step | Action | Validation | Owner |
|------|--------|------------|-------|
| 1 | [Permanent fix description] | [Success criteria] | [Team/person] |
| 2 | [Follow-up action] | [Success criteria] | [Team/person] |

### Prevention Improvements

| Category | Recommendation | Priority |
|----------|---------------|----------|
| Monitoring | [Specific alert or metric to add] | High/Med/Low |
| Process | [Process change description] | High/Med/Low |
| Architecture | [Infrastructure improvement] | High/Med/Low |

## 5. Proof of Work

### Inputs Consulted

| Source Type | Source | Findings |
|-------------|--------|----------|
| Logs | [pod/container name] | [Key finding from logs] |
| Events | [kubectl events scope] | [Key finding from events] |
| Metrics | [prometheus/grafana] | [Key observation] |

### Commands Executed

```bash
# [Category description]
[command 1]
[command 2]
[command 3]

# [Next category if applicable]
[command 4]
```

### Constraints Documented
- [Time constraint: e.g., investigation limited to X minutes]
- [Access constraint: e.g., no access to node logs]
- [Data constraint: e.g., logs older than Y not available]

## 6. Supporting Evidence

### Log Excerpts

<details>
<summary>Pod logs: [pod-name] (click to expand)</summary>

```
[paste relevant log lines with timestamps]
```

</details>

### kubectl Output

<details>
<summary>kubectl describe pod [pod-name]</summary>

```
[paste kubectl output]
```

</details>

### Additional Evidence

<details>
<summary>[Description of evidence type]</summary>

```
[paste output or data]
```

</details>

---END MANDATORY TEMPLATE---

### Template Compliance Rules

**Section Headers:**
- MUST use exact section numbers and names (0-6)
- MUST include all sections even if data unavailable
- If data unavailable, state: "Not available due to [reason]"

**Formatting:**
- MUST preserve table structures
- MUST use `[FACT-n]` labels for all facts
- MUST use `[INF-n]` labels for all inferences
- MUST use `<details>` tags for collapsible evidence

**Content:**
- Keep sections concise per P3/P4 depth guidelines
- Use bullet points, not paragraphs, where shown
- Include source attribution for all facts
- Provide falsification tests for all hypotheses

**Common Violations to Avoid:**
- ❌ Creating sections named "Incident Overview", "Primary Issue", "Key Findings"
- ❌ Mixing facts and inferences without labels
- ❌ Providing hypotheses without Evidence For/Against structure
- ❌ Omitting the "Most Dangerous Assumption"
- ❌ Adding prose paragraphs instead of structured tables
- ❌ Skipping Supporting Evidence section

### Section 0: Executive Triage Card

**Purpose**: Enable incident commanders to make decisions in 30-60 seconds.

```markdown
## Executive Triage Card

| Field | Value |
|-------|-------|
| **Status** | 🔴 Active Incident / 🟡 Degraded / 🟢 Resolved |
| **Severity** | P1/P2/P3/P4 (see severity table) |
| **Impact** | [Blast radius: pod/namespace/multi-namespace/cluster-wide] |
| **Duration** | Started: [timestamp], Ongoing: [duration] |

### Primary Hypothesis
**[Hypothesis statement]** — Confidence: [High/Medium/Low]

⚠️ **Most Dangerous Assumption**: [What assumption, if wrong, would most change our approach]

### Top 3 Recommended Actions

| Priority | Action | Expected Outcome | Risk |
|----------|--------|------------------|------|
| 1 | [Immediate action] | [What it fixes] | [Low/Med/High] |
| 2 | [Secondary action] | [What it fixes] | [Low/Med/High] |
| 3 | [Tertiary action] | [What it fixes] | [Low/Med/High] |

### Escalation Triggers
- [ ] Escalate if: [condition 1]
- [ ] Escalate if: [condition 2]

### Alternative Hypotheses Considered
1. [H2: Alternative hypothesis] — Confidence: [X%], Why deprioritized: [reason]
2. [H3: Another alternative] — Confidence: [X%], Why deprioritized: [reason]
```

### Section 1: Problem Statement

**Purpose**: Define what's broken, when it started, and what success looks like.

```markdown
## Problem Statement

### Symptoms
- [Observable symptom 1]
- [Observable symptom 2]
- [Observable symptom 3]

### Timeline
- **First detected**: [timestamp, detection method]
- **Reported by**: [source: alert, user, automated check]
- **Current duration**: [time since first detection]

### Exit Criteria Checklist
- [ ] [Specific measurable outcome 1]
- [ ] [Specific measurable outcome 2]
- [ ] [Specific measurable outcome 3]
```

### Section 2: Assessment & Findings

**Purpose**: Separate verified facts from derived inferences with explicit confidence levels.

```markdown
## Assessment & Findings

### Classification

| Aspect | Value |
|--------|-------|
| **Category** | [Pod/Service/Storage/Node/Network/Helm/Cluster] |
| **Blast Radius** | [Single pod/Namespace/Multi-namespace/Cluster-wide] |
| **User Impact** | [None/Degraded/Partial outage/Full outage] |

### Scope

| Status | Resources |
|--------|-----------|
| **Confirmed Affected** | [pod-1, pod-2, service-x] |
| **Suspected Affected** | [deployment-y, namespace-z] |
| **Confirmed Unaffected** | [namespace-a, service-b] |

### Observed Facts
> Facts are directly verifiable from kubectl output, logs, or metrics.

- **[FACT-1]** [Description] — Source: `kubectl get pods -n namespace`
- **[FACT-2]** [Description] — Source: Pod logs, timestamp
- **[FACT-3]** [Description] — Source: `kubectl describe node`

### Derived Inferences
> Inferences are conclusions drawn from facts. Each includes confidence level.

- **[INF-1]** [Inference statement] — Confidence: [High/Medium/Low]
  - Based on: FACT-1, FACT-2
  - Could be wrong if: [falsification condition]
- **[INF-2]** [Inference statement] — Confidence: [High/Medium/Low]
  - Based on: FACT-3
  - Could be wrong if: [falsification condition]

### What Changed
> Recent changes that may be correlated with the incident.

| When | What Changed | Who/What | Correlation |
|------|-------------|----------|-------------|
| [timestamp] | [change description] | [actor] | [likely/possible/unlikely] |

### Constraints Encountered
- [Access limitation 1]
- [Missing data 1]
- [Tool limitation 1]
```

### Section 3: Root Cause Analysis

**Purpose**: Present ranked hypotheses with evidence and explicit falsification tests.

```markdown
## Root Cause Analysis

### H1: [Primary Hypothesis] — Confidence: [High/Medium/Low]

**Statement**: [Clear, specific hypothesis about root cause]

**Evidence For**:
- [Supporting evidence 1] (FACT-1)
- [Supporting evidence 2] (FACT-2)

**Evidence Against**:
- [Contradicting evidence, if any]

**Falsification Test**: [Specific test that would disprove this hypothesis]
- Command: `[kubectl command or check]`
- If result is [X], hypothesis is falsified

---

### H2: [Secondary Hypothesis] — Confidence: [Medium/Low]

**Statement**: [Alternative root cause hypothesis]

**Evidence For**:
- [Supporting evidence]

**Evidence Against**:
- [Why this is less likely than H1]

**Falsification Test**: [How to disprove]

---

### H3: [Tertiary Hypothesis] — Confidence: [Low]

**Statement**: [Third alternative]

**Why Deprioritized**: [Specific reason]

---

### Remaining Unknowns
- [ ] [Unknown 1]: Would change analysis if discovered
- [ ] [Unknown 2]: Requires additional access/data
```

### Section 4: Remediation Plan

**Purpose**: Provide actionable steps with validation and rollback procedures.

```markdown
## Remediation Plan

### Immediate Mitigation

| Step | Action | Validation | Rollback |
|------|--------|------------|----------|
| 1 | [Action command] | [How to verify success] | [How to undo] |
| 2 | [Action command] | [How to verify success] | [How to undo] |

### Fix Forward

| Step | Action | Validation | Owner |
|------|--------|------------|-------|
| 1 | [Permanent fix action] | [Success criteria] | [Team/person] |
| 2 | [Follow-up action] | [Success criteria] | [Team/person] |

### Prevention Improvements

| Category | Recommendation | Priority |
|----------|---------------|----------|
| Monitoring | [Add alert for X] | High |
| Process | [Change Y procedure] | Medium |
| Architecture | [Consider Z improvement] | Low |
```

### Section 5: Proof of Work

**Purpose**: Document what was investigated for auditing and future reference.

```markdown
## Proof of Work

### Inputs Consulted

| Source Type | Source | Findings |
|-------------|--------|----------|
| Logs | [pod/container logs] | [Key finding] |
| Events | [kubectl events] | [Key finding] |
| Metrics | [prometheus/grafana] | [Key finding] |
| Documentation | [runbook, wiki] | [Relevant info] |
| Team Input | [person/channel] | [Key insight] |

### Commands Executed

```bash
# Cluster state assessment
kubectl get pods -n namespace -o wide
kubectl describe pod problem-pod -n namespace
kubectl logs problem-pod -n namespace --tail=100

# Event correlation
kubectl get events -n namespace --sort-by='.lastTimestamp'

# Resource analysis
kubectl top pods -n namespace
kubectl describe node affected-node
```

### Constraints Documented
- [Time constraint: investigation limited to X minutes]
- [Access constraint: no access to Y]
- [Data constraint: logs older than Z not available]
```

### Section 6: Supporting Evidence

**Purpose**: Provide raw output for verification and future reference.

```markdown
## Supporting Evidence

### Log Excerpts

<details>
<summary>Pod logs: problem-pod (click to expand)</summary>

```
[timestamp] ERROR: [error message]
[timestamp] WARN: [warning message]
[timestamp] INFO: [relevant context]
```

</details>

### kubectl Output

<details>
<summary>kubectl describe pod problem-pod (click to expand)</summary>

```
Name:         problem-pod
Namespace:    production
...
Events:
  Type     Reason     Age   From     Message
  ----     ------     ----  ----     -------
  Warning  BackOff    2m    kubelet  Back-off restarting failed container
```

</details>

### Metrics Snapshots

<details>
<summary>Resource usage at incident time (click to expand)</summary>

[Include relevant graphs, metrics, or data points]

</details>
```

### Severity Guidelines

Use these criteria to assign incident severity:

| Severity | Criteria | Response Time | Examples |
|----------|----------|---------------|----------|
| **P1 - Critical** | Complete service outage, data loss risk, security breach | Immediate (< 15 min) | Cluster unreachable, all pods crashing, data corruption |
| **P2 - High** | Major feature unavailable, significant user impact | < 1 hour | Key service degraded, 50%+ pods affected, persistent failures |
| **P3 - Medium** | Minor feature impact, workaround available | < 4 hours | Single pod issues, intermittent errors, non-critical service |
| **P4 - Low** | Minimal impact, cosmetic issues | < 24 hours | Warning events, minor config drift, documentation gaps |

### Blast Radius Categories

Use these categories to describe incident scope:

| Blast Radius | Description | Typical Causes |
|--------------|-------------|----------------|
| **Single Pod** | One pod affected, no broader impact | App bug, resource limits, image issues |
| **Namespace** | Multiple pods in one namespace affected | Namespace quota, shared secret/configmap, network policy |
| **Multi-Namespace** | Multiple namespaces impacted | Node failure, CNI issues, shared infrastructure |
| **Cluster-Wide** | Entire cluster degraded or unavailable | Control plane issues, etcd problems, CNI failure, node exhaustion |

### Fact vs Inference Methodology

**Facts** are directly observable and independently verifiable:
- Command output (kubectl get, describe, logs)
- Timestamps from events or logs
- Metric values at specific points in time
- Configuration values from manifests

**Inferences** are conclusions drawn from facts:
- Root cause determinations
- Correlations between events
- Predictions about behavior
- Assessments of impact

**Labeling Convention**:
- Prefix facts with `[FACT-n]` for traceability
- Prefix inferences with `[INF-n]` and include:
  - Confidence level (High/Medium/Low)
  - Supporting facts by reference
  - Falsification condition ("Could be wrong if...")

**Confidence Levels**:
- **High**: Multiple corroborating facts, matches known patterns, no contradicting evidence
- **Medium**: Some supporting facts, plausible explanation, minor gaps in evidence
- **Low**: Limited evidence, speculative, alternative explanations equally likely

### Hypothesis Ranking

When presenting root cause hypotheses:

1. **Rank by confidence**: Present highest confidence hypothesis first (H1)
2. **Provide evidence both ways**: List evidence for AND against each hypothesis
3. **Include falsification tests**: Specify what would disprove each hypothesis
4. **Identify the most dangerous assumption**: What assumption, if wrong, would most change the recommended approach?

**Falsification Test Format**:
```
**Falsification Test**: [Description of test]
- Command: `[specific command to run]`
- Expected if hypothesis is TRUE: [result]
- Expected if hypothesis is FALSE: [result]
```

**Example**:
```
### H1: OOM Kill due to memory leak — Confidence: High

**Falsification Test**: Check if memory usage grows over time
- Command: `kubectl top pod app-pod -n prod --containers`
- Expected if TRUE: Memory usage near limit, increasing trend
- Expected if FALSE: Memory usage stable, well below limit
```

### Report Generation Checklist

Before finalizing a report, verify:

- [ ] Executive Triage Card can be understood in 30-60 seconds
- [ ] All facts are labeled and include source references
- [ ] All inferences include confidence levels and falsification conditions
- [ ] At least 2-3 hypotheses are presented with ranking
- [ ] "Most dangerous assumption" is explicitly identified
- [ ] Remediation steps include validation AND rollback procedures
- [ ] Proof of Work documents all commands executed
- [ ] Constraints and limitations are acknowledged

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
