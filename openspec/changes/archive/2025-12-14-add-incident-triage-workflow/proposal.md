# Change: Add Incident Triage Workflow

## Why

The current k8s-troubleshooter skill has good domain-specific scripts (pod, network, storage, helm) but lacks the "golden path" triage workflow that production operators use:

1. **No evidence capture** - No `kubectl cluster-info dump` integration for preserving cluster state before investigation
2. **No blast radius assessment** - Scripts assume you already know what's broken; missing "is this one pod or the whole cluster?"
3. **No structured decision tree** - User must choose which script to run; ChatGPT analysis shows operators classify by symptom first
4. **Verbose readiness check missing** - Scripts use `/healthz` but not `/readyz?verbose` which operators prefer for human-readable status

The ChatGPT assessment provides a production-grade "stabilize -> capture evidence -> isolate layer -> deep dive" pattern used by advanced operators.

## What Changes

1. **Add `incident_triage.sh` script** - New entry point that:
   - Captures evidence first (`cluster-info dump`, nodes, pods, warning events)
   - Assesses blast radius (single namespace vs cluster-wide)
   - Checks control plane health (`/readyz?verbose`)
   - Classifies by symptom and recommends appropriate workflow
   - Outputs structured triage report

2. **Enhance `cluster_health_check.sh`** - Add verbose readiness check

3. **Add triage decision tree to documentation** - Runbook-style flowchart for symptom-based classification

4. **Update SKILL.md** - Add incident response entry point before domain-specific workflows

## Impact

- Affected specs: `k8s-troubleshooter`
- New files:
  - `skills/k8s-troubleshooter/scripts/incident_triage.sh`
  - `skills/k8s-troubleshooter/reference/incident-response.md`
- Modified files:
  - `skills/k8s-troubleshooter/scripts/cluster_health_check.sh` (add /readyz?verbose)
  - `skills/k8s-troubleshooter/SKILL.md` (add incident triage workflow)

Breaking changes: None (adds new capability)
