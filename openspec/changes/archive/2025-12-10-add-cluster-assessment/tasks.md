# Tasks: Add Cluster Assessment Capability

## Task Order

Tasks are ordered to deliver user-visible progress incrementally with validation at each step.

## Checklist

- [x] Task 1: Create cluster assessment reference documentation
- [x] Task 2: Implement cluster assessment script
- [x] Task 3: Add cluster assessment workflow to SKILL.md
- [x] Task 4: Update skill README with assessment features
- [x] Task 5: Create spec delta for cluster-assessment capability
- [x] Task 6: Validate complete proposal

---

### Task 1: Create cluster assessment reference documentation

**What**: Create comprehensive reference document explaining cluster assessment methodology, use cases, and best practices.

**Deliverable**: `skills/k8s-troubleshooter/references/cluster-assessment.md`

**Validation**:
- Document includes all sections: overview, use cases, workflow phases, automation patterns
- Comparison table clearly distinguishes assessment from health check
- Usage examples are complete and accurate
- Best practices section covers before/during/after assessment

**Dependencies**: None

---

### Task 2: Implement cluster assessment script

**What**: Create bash script that automates cluster data collection, analysis, and markdown report generation.

**Deliverable**: `skills/k8s-troubleshooter/scripts/cluster_assessment.sh`

**Features**:
- Command-line options: `-o/--output`, `-c/--kubeconfig`, `-h/--help`
- Data collection functions for nodes, pods, workloads, storage, events
- API health checks (/healthz, /readyz, /livez)
- Markdown report generation with template substitution
- Default timestamped output filename

**Validation**:
- Script executes without errors
- Generates valid markdown output
- All placeholders are replaced with actual data
- CLI options work as documented
- Passes shellcheck validation
- Functions properly with standard kubectl access

**Dependencies**: Task 1 (reference documentation provides specification)

---

### Task 3: Add cluster assessment workflow to SKILL.md

**What**: Add Workflow 7: Cluster Assessment to SKILL.md with comprehensive guidance.

**Deliverable**: Updated `skills/k8s-troubleshooter/SKILL.md`

**Content**:
- Overview and when to use
- Assessment phases (collection, analysis, report generation, recommendations)
- Script usage examples
- Report sections overview
- Comparison table: Health Check vs Assessment
- Cross-reference to detailed documentation

**Validation**:
- Workflow follows existing skill structure and patterns
- `/cluster-assessment` trigger is documented
- Examples are accurate and complete
- Integration with existing workflows is clear
- Cross-references are correct

**Dependencies**: Task 1, Task 2

---

### Task 4: Update skill README with assessment features

**What**: Update README.md to document new cluster assessment capabilities.

**Deliverable**: Updated `skills/k8s-troubleshooter/README.md`

**Changes**:
- Add "Comprehensive cluster assessment and reporting" to feature list
- Add `cluster-assessment.md` to references structure section
- Add `cluster_assessment.sh` to scripts section
- Add `/cluster-assessment` to trigger patterns
- Add assessment script usage example with comparison to health check
- Add cluster-assessment reference to deep-dive guides section

**Validation**:
- All new files/features are documented
- Structure section matches actual directory layout
- Usage examples are accurate
- Comparison clarifies assessment vs health check distinction

**Dependencies**: Task 1, Task 2, Task 3

---

### Task 5: Create spec delta for cluster-assessment capability

**What**: Create spec delta documenting new cluster assessment requirements.

**Deliverable**: `openspec/changes/add-cluster-assessment/specs/cluster-assessment/spec.md`

**Requirements**:
- Cluster assessment workflow triggering and metadata
- Comprehensive data collection phases
- Analysis and health scoring
- Report structure and format
- Automation and CI/CD integration
- Clear distinction from quick health checks

**Validation**:
- Each requirement has at least one scenario with WHEN/THEN structure
- Requirements are verifiable and testable
- Scenarios cover key use cases and edge cases
- Requirements align with implementation in tasks 1-4

**Dependencies**: Task 1, Task 2, Task 3, Task 4 (spec documents implemented behavior)

---

### Task 6: Validate complete proposal

**What**: Run OpenSpec validation and resolve all issues.

**Commands**:
```bash
openspec validate add-cluster-assessment --strict
```

**Validation**:
- No validation errors
- No validation warnings
- All requirements have scenarios
- All scenarios are well-formed
- Cross-references are valid

**Dependencies**: All previous tasks

---

## Parallelization Opportunities

- Tasks 1 and 2 can be developed in parallel (reference doc and script)
- Task 3 and 4 can be done in parallel after tasks 1-2 complete
- Task 5 should be done after implementation (tasks 1-4) to document actual behavior

## Testing Strategy

1. **Script Testing**
   - Run against test Kubernetes cluster
   - Verify report generation with various cluster states
   - Test CLI options (-o, -c, -h)
   - Validate markdown syntax

2. **Documentation Testing**
   - Verify all examples execute correctly
   - Cross-check references between files
   - Validate markdown rendering

3. **Integration Testing**
   - Verify `/cluster-assessment` trigger activates workflow
   - Test skill with Claude Code
   - Ensure no conflicts with existing workflows

## Completion Criteria

All tasks completed AND:
- OpenSpec validation passes with --strict flag
- Script executes successfully against test cluster
- Documentation is complete and accurate
- All cross-references are valid
- No breaking changes to existing workflows

---

## Completion Notes

**Status**: ✅ ALL TASKS COMPLETED

**Implementation Summary**:

1. ✅ **Task 1 - Reference Documentation**: Created comprehensive `references/cluster-assessment.md` (458 lines) covering assessment methodology, use cases, workflow phases, automation patterns, and best practices.

2. ✅ **Task 2 - Assessment Script**: Implemented `scripts/cluster_assessment.sh` (385 lines) with:
   - CLI options: `-o/--output`, `-c/--kubeconfig`, `-h/--help`
   - Data collection functions for control plane, nodes, pods, workloads, storage, events
   - Markdown report generation with template substitution
   - Default timestamped output filenames

3. ✅ **Task 3 - SKILL.md Workflow**: Added Workflow 7: Cluster Assessment to `SKILL.md` with:
   - Overview and when to use section
   - Four assessment phases documented
   - Script usage examples
   - Comparison table: Health Check vs Assessment
   - Report sections overview

4. ✅ **Task 4 - README Updates**: Updated `README.md` with:
   - Assessment capability in feature list
   - File structure documentation
   - `/cluster-assessment` trigger pattern
   - Script usage examples
   - Reference to deep-dive guide

5. ✅ **Task 5 - Spec Delta**: Created `specs/cluster-assessment/spec.md` with 8 comprehensive requirements covering workflow triggering, data collection, analysis, reporting, automation, documentation, and integration.

6. ✅ **Task 6 - Validation**: OpenSpec validation passed with `--strict` flag.

**Files Modified**:
- `skills/k8s-troubleshooter/README.md` (modified)
- `skills/k8s-troubleshooter/SKILL.md` (modified)

**Files Created**:
- `skills/k8s-troubleshooter/references/cluster-assessment.md` (new)
- `skills/k8s-troubleshooter/scripts/cluster_assessment.sh` (new)

**Ready for Archive**: Yes - All deliverables complete, validation passed, no breaking changes.
