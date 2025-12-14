# Tasks for add-incident-triage-workflow

## Implementation Tasks

- [x] 1. **Create `incident_triage.sh` script**
   - Accept optional `--output-dir` for evidence capture location
   - Accept optional `--namespace` to scope to specific namespace
   - Accept optional `--skip-dump` to skip full cluster dump (faster triage)

- [x] 2. **Implement evidence capture phase**
   - Run `kubectl cluster-info dump --all-namespaces --output-directory=<dir>` (optional, with --skip-dump flag)
   - Capture `kubectl get nodes -o wide`
   - Capture `kubectl get pods -A -o wide`
   - Capture `kubectl get events --all-namespaces --types=Warning`
   - Store captures in timestamped output directory

- [x] 3. **Implement control plane health check**
   - Query `/readyz?verbose` for human-readable status
   - Parse response to identify failing checks
   - Output clear "control plane healthy/degraded" status

- [x] 4. **Implement blast radius assessment**
   - Count affected namespaces (pods not Running)
   - Count affected nodes (NotReady or pressure conditions)
   - Classify as: "single pod", "single namespace", "multiple namespaces", "cluster-wide"

- [x] 5. **Implement symptom classifier**
   - Detect Pending pods -> suggest scheduling/capacity investigation
   - Detect CrashLoopBackOff/OOMKilled -> suggest pod diagnostics
   - Detect DNS/network events -> suggest network debugging
   - Detect FailedMount events -> suggest storage check
   - Detect Helm release issues -> suggest helm debug

- [x] 6. **Generate triage report**
   - Output structured summary: blast radius, control plane status, top symptoms, recommended workflows
   - Include specific commands to run based on classification
   - Support both terminal output and markdown file output

- [x] 7. **Update `cluster_health_check.sh`**
   - Add `/readyz?verbose` query alongside existing `/healthz`
   - Parse and display component-level status

- [x] 8. **Create `reference/incident-response.md`**
   - Document triage decision tree (text-based flowchart)
   - Include "first 5 minutes" checklist
   - Document evidence preservation best practices
   - Cross-reference to specific diagnostic scripts

- [x] 9. **Update SKILL.md**
   - Add "Incident Response" section before domain-specific workflows
   - Document `incident_triage.sh` as primary entry point for production incidents
   - Include quick reference to decision tree

## Validation Tasks

- [x] 10. **Test against healthy cluster**
    - Run triage script
    - Verify "no issues detected" report
    - Verify control plane shows healthy

- [x] 11. **Test against cluster with induced failures**
    - Create CrashLoopBackOff pod
    - Create Pending pod (resource constraints)
    - Run triage script
    - Verify correct symptom classification
    - Verify recommended workflows match induced failures

- [x] 12. **Test blast radius detection**
    - Induce single-namespace failure
    - Verify "single namespace" classification
    - Induce multi-namespace failure
    - Verify "multiple namespaces" classification

- [x] 13. **Validate script portability**
    - Test on macOS
    - Test on Linux
    - Verify no GNU-specific constructs

- [x] 14. **Validate OpenSpec compliance**
    - Run `openspec validate add-incident-triage-workflow --strict`
