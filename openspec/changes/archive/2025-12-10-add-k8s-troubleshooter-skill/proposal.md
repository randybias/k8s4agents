# Change: Add Kubernetes Troubleshooter Claude Skill

## Why

Kubernetes troubleshooting is one of the most complex operational tasks, requiring deep knowledge of cluster architecture, resource relationships, networking, storage, and event correlation. Operators frequently struggle with:
- Identifying root causes from cascading symptoms
- Knowing which kubectl commands to run and in what sequence
- Correlating events, logs, and resource states across namespaces
- Applying production-safe diagnostic patterns without making issues worse

A comprehensive Claude Skill for Kubernetes troubleshooting will encode expert diagnostic workflows, production-safe command patterns, and systematic investigation methodologies that transform Claude into a Kubernetes architect and operator capable of guiding users through complex cluster issues.

## What Changes

- **NEW**: `k8s-troubleshooter` Claude Skill with:
  - SKILL.md containing comprehensive troubleshooting workflows
  - Progressive disclosure via `references/` for domain-specific deep dives
  - Production-safe `scripts/` for common diagnostic operations
  - Systematic diagnostic decision trees for pods, services, networking, storage, and cluster health

- **Source-Aligned**: Reuse proven patterns from top-ranked Kubernetes Claude skills and plugins (wshobson/agents, devops-claude k8s-troubleshooter, claude-k8s-troubleshooter) plus canonical Kubernetes docs to ensure accurate, production-safe workflows.

- **Triage Experience**:
  - Symptom-first entry points (pods, services/DNS, storage, nodes, control plane)
  - Slash-command style triggers for common flows (/pod-debug, /svc-debug, /full-diag) inspired by claude-k8s-troubleshooter
  - Phased triage (baseline → inspect → correlate → deep dive) with clear stop conditions

- **Observability-First**:
  - Logs/events correlation recipes derived from Kubernetes logging/event best practices
  - Guidance for collecting timelines and cross-resource evidence without mutating cluster state

- **Scenario Library**:
  - Real-world incident playbooks (CrashLoopBackOff, OOMKilled, DNS failures, node pressure, stuck Helm releases) mapped from ranked scenario sources
  - Cloud-aware CSI and network policy troubleshooting with provider notes (EKS/AKS/GKE, Calico)

- **Integration Guidance**:
  - MCP server patterns for safe kubectl access from Claude
  - Optional AI tooling references (k8sgpt) for automated signal gathering while preserving human-in-the-loop control

- **Skill Structure**:
  - Core troubleshooting workflows (pod lifecycle, service connectivity, storage, networking)
  - Incident response playbooks (CrashLoopBackOff, OOMKilled, DNS failures, node pressure)
  - Helm chart debugging patterns
  - CNI/Calico network policy troubleshooting
  - CSI storage driver diagnostics
  - Read-only, production-safe kubectl command patterns
  - Integration guidance for MCP servers and AI-assisted diagnostics

## Impact

- Affected specs: NEW `k8s-troubleshooter` capability
- Affected code: New skill directory at project root
- Dependencies: kubectl CLI access, optional MCP server integration
- Reference alignment: Match command patterns and safety guardrails from wshobson/agents and devops-claude k8s-troubleshooter skills

## Source Application Plan

- **Rank 1–2 skills (wshobson/agents, devops-claude k8s-troubleshooter)**: Mirror frontmatter fields, trigger phrasing, safety guardrails, and diagnostic step ordering; copy reusable prompts/command recipes where applicable.
- **Rank 3 canonical Kubernetes docs**: Ground all workflows and scripts in documented kubectl debug/logs/describe/get patterns; avoid deprecated flags.
- **Rank 4 claude-k8s-troubleshooter config**: Adopt phased triage flow and slash-command entry points; reuse read-only command gating.
- **Rank 5 logging/events best practices**: Embed event/log timeline collection and interpretation steps into workflows and references.
- **Rank 6+ scenario/Helm/network/storage sources**: Expand incident library to cover networking (Calico/CNI), CSI provider specifics, Helm upgrade failures, and node-level issues.

## Source Materials

This skill synthesizes knowledge from 25 ranked sources including:
1. Existing Claude Code K8s plugins (wshobson/agents, ahmedasmar/devops-claude-skills)
2. Official Kubernetes debugging documentation
3. Specialized troubleshooter configurations (claude-k8s-troubleshooter)
4. Real-world scenario guides and CNCF best practices
5. Helm debugging documentation
6. Calico/CNI and CSI storage troubleshooting guides
7. MCP server patterns for AI-driven cluster introspection
8. K8sGPT and other AI-assisted diagnostic tools

## Test Plan

### Unit Validation
- [ ] SKILL.md passes Claude skill validation (frontmatter, structure)
- [ ] All scripts execute without errors on test inputs
- [ ] Reference files follow progressive disclosure patterns
- [ ] Crosswalk against wshobson/agents + devops-claude k8s-troubleshooter for structural parity and safety guardrails

### Functional Testing
- [ ] Skill triggers on appropriate prompts ("debug my pods", "why is my service unreachable")
- [ ] Diagnostic workflows produce correct kubectl commands
- [ ] Incident response playbooks cover common failure scenarios
- [ ] Slash-command triggers (/pod-debug, /svc-debug, /full-diag) map to correct workflows
- [ ] Logs/events correlation steps surface timeline and anomalies

### Integration Testing
- [ ] Test against real Kubernetes cluster with sample workloads
- [ ] Validate production-safe commands don't modify cluster state
- [ ] Test progressive disclosure (references loaded only when needed)
- [ ] Validate MCP server guidance works with at least one kubectl MCP server

### Parity/Regression Checks
- [ ] Compare workflows and guardrails to ranks 1–5 sources and close any gaps

### User Acceptance
- [ ] Walk through 5+ real-world troubleshooting scenarios
- [ ] Verify output matches expected diagnostic patterns
- [ ] Confirm skill adapts to different cluster configurations (EKS, AKS, GKE, bare-metal)
