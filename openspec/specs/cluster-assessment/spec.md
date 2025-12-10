# cluster-assessment Specification

## Purpose

This specification defines the cluster assessment capability for the k8s-troubleshooter skill. Cluster assessment provides comprehensive evaluation and documentation of Kubernetes cluster health, capacity, security posture, and operational readiness.

Unlike quick health checks designed for immediate troubleshooting, cluster assessment generates detailed markdown reports suitable for:
- Baseline documentation of new or inherited clusters
- Capacity planning and resource utilization analysis
- Audit and compliance documentation
- Quarterly operational reviews
- Handoff documentation when transferring cluster ownership

The assessment workflow collects data across control plane, nodes, workloads, storage, networking, and events; analyzes this data to identify issues and compute health scores; and generates structured reports with prioritized recommendations.
## Requirements
### Requirement: Cluster Assessment Workflow Triggering

The k8s-troubleshooter skill SHALL provide a cluster assessment workflow that can be triggered via the `/cluster-assessment` pattern and generates comprehensive reports.

#### Scenario: User requests cluster assessment

- **WHEN** user asks "generate a cluster assessment report" or uses `/cluster-assessment` trigger
- **THEN** the skill MUST initiate the cluster assessment workflow

#### Scenario: Workflow distinction from health check

- **WHEN** skill describes cluster assessment vs health check
- **THEN** documentation MUST clearly distinguish:
  - Assessment: 2-5 minutes, markdown report, full analysis, prioritized recommendations, documentation use case
  - Health check: 30 seconds, terminal output, critical issues only, no recommendations, quick status use case

#### Scenario: Assessment workflow metadata

- **WHEN** cluster assessment workflow is loaded
- **THEN** it MUST include clear triggering description that references capacity planning, audits, documentation, and comprehensive analysis

---

### Requirement: Comprehensive Data Collection

The cluster assessment workflow SHALL collect data across control plane, nodes, workloads, storage, networking, and events.

#### Scenario: Control plane health data collection

- **WHEN** assessment collects control plane data
- **THEN** it MUST query API server health endpoints: /healthz, /readyz, /livez
- **AND** collect control plane component status (kube-system pods)

#### Scenario: Node infrastructure data collection

- **WHEN** assessment collects node data
- **THEN** it MUST retrieve:
  - Node status and conditions (Ready, MemoryPressure, DiskPressure, PIDPressure)
  - Resource capacity and allocatable
  - Kubernetes version per node
  - Optional: resource usage metrics if metrics-server available

#### Scenario: Workload data collection

- **WHEN** assessment collects workload data
- **THEN** it MUST retrieve:
  - All pods across all namespaces with status
  - Deployments, StatefulSets, DaemonSets counts and status
  - Failed and pending pods
  - Optional: pod resource usage if metrics-server available

#### Scenario: Storage infrastructure data collection

- **WHEN** assessment collects storage data
- **THEN** it MUST retrieve:
  - All PVCs and PVs with status and capacity
  - Available StorageClasses
  - Storage utilization where available

#### Scenario: Network configuration data collection

- **WHEN** assessment collects network data
- **THEN** it MUST retrieve:
  - CNI pod status (calico, flannel, cilium, weave, etc.)
  - Services and endpoints
  - Network policies (if any)
  - DNS pod health (CoreDNS/kube-dns)

#### Scenario: Event data collection

- **WHEN** assessment collects events
- **THEN** it MUST retrieve recent events sorted by timestamp
- **AND** separate Warning events for visibility

---

### Requirement: Analysis and Health Scoring

The cluster assessment workflow SHALL analyze collected data and compute a health score with identified issues.

#### Scenario: Resource overcommitment analysis

- **WHEN** assessment analyzes resource allocation
- **THEN** it MUST:
  - Calculate CPU and memory limit overcommitment per node
  - Identify nodes with >100% overcommitment
  - Flag overcommitment as a risk factor

#### Scenario: Failure detection

- **WHEN** assessment analyzes pod status
- **THEN** it MUST identify:
  - Pods in Failed state with reasons
  - Pods with high restart counts
  - Pending pods with scheduling reasons

#### Scenario: Node pressure detection

- **WHEN** assessment analyzes node conditions
- **THEN** it MUST identify nodes with:
  - MemoryPressure condition
  - DiskPressure condition
  - PIDPressure condition
  - High resource utilization (>80% CPU/Memory)

#### Scenario: Security posture evaluation

- **WHEN** assessment evaluates security
- **THEN** it SHOULD check for:
  - Network policy coverage
  - RBAC configuration
  - Authentication methods
  - Pod security standards (where applicable)

#### Scenario: Health score computation

- **WHEN** assessment computes overall health score
- **THEN** it MUST:
  - Start with base score of 100
  - Apply deductions for issues (failed pods, node pressure, overcommitment, missing monitoring, etc.)
  - Provide score ranges interpretation:
    - 90-100: Excellent
    - 75-89: Good
    - 60-74: Fair
    - Below 60: Poor

---

### Requirement: Structured Report Generation

The cluster assessment workflow SHALL generate a markdown report with standardized structure suitable for documentation and version control.

#### Scenario: Report format and structure

- **WHEN** assessment generates a report
- **THEN** the report MUST be valid markdown
- **AND** include sections:
  1. Executive Summary (cluster name, health score, critical findings)
  2. Control Plane Health
  3. Node Infrastructure
  4. Resource Allocation
  5. Workload Status
  6. Storage Infrastructure
  7. Network Configuration
  8. Security Posture
  9. Recent Events
  10. Recommendations (prioritized as High/Medium/Low)

#### Scenario: Executive summary content

- **WHEN** report includes executive summary
- **THEN** it MUST contain:
  - Cluster identification (name/context)
  - Kubernetes version
  - Assessment timestamp
  - Overall health score
  - Count of critical issues

#### Scenario: Recommendations prioritization

- **WHEN** report includes recommendations
- **THEN** recommendations MUST be organized by priority:
  - **High Priority**: Security issues, capacity critical, control plane problems
  - **Medium Priority**: Operational improvements, monitoring gaps, best practices
  - **Low Priority**: Optimizations, minor improvements

#### Scenario: Recommendation detail structure

- **WHEN** report lists a recommendation
- **THEN** each recommendation MUST include:
  - Problem statement (what the issue is)
  - Impact assessment (why it matters)
  - Specific action items (how to fix)
  - Reference documentation links (where to learn more)

#### Scenario: Report persistence and naming

- **WHEN** assessment script generates output
- **THEN** default filename MUST include timestamp: `cluster-assessment-YYYYMMDD-HHMMSS.md`
- **AND** support custom output filename via `-o/--output` option

---

### Requirement: Assessment Script Automation

The cluster assessment SHALL be provided as an executable bash script that automates data collection and report generation.

#### Scenario: Script CLI interface

- **WHEN** assessment script is invoked
- **THEN** it MUST support command-line options:
  - `-o, --output FILE`: Specify output filename
  - `-c, --kubeconfig FILE`: Specify kubeconfig path
  - `-h, --help`: Display usage information

#### Scenario: Script prerequisites validation

- **WHEN** script executes
- **THEN** it MUST:
  - Verify kubectl is installed and available
  - Verify connectivity to Kubernetes cluster
  - Exit with clear error if prerequisites not met

#### Scenario: Script status reporting

- **WHEN** script executes data collection
- **THEN** it MUST provide progress indicators:
  - "Collecting cluster data..."
  - "Analyzing nodes..."
  - "Analyzing pods..."
  - "Generating report: <filename>"
  - "Assessment complete! Report saved to: <filename>"

#### Scenario: Script error handling

- **WHEN** script encounters errors during data collection
- **THEN** it MUST:
  - Continue with partial data where possible
  - Note missing data in report
  - Exit with non-zero status code on critical failures

#### Scenario: Script safety guarantees

- **WHEN** assessment script executes
- **THEN** it MUST:
  - Use only read-only kubectl operations
  - Not modify any cluster resources
  - Not require elevated privileges beyond read access

---

### Requirement: CI/CD and Automation Integration

The cluster assessment workflow SHALL support integration with CI/CD pipelines and scheduled automation.

#### Scenario: Scriptable invocation

- **WHEN** assessment is invoked programmatically
- **THEN** script MUST:
  - Support non-interactive execution
  - Exit with appropriate status codes
  - Output parseable progress to stderr
  - Write report to specified file or stdout

#### Scenario: Multi-cluster support

- **WHEN** assessing multiple clusters
- **THEN** script MUST:
  - Support kubeconfig selection via `-c` option or KUBECONFIG env var
  - Generate cluster-specific reports
  - Include cluster context in report identification

#### Scenario: Regular scheduled assessments

- **WHEN** used in cron or scheduled pipelines
- **THEN** script MUST:
  - Support timestamped output filenames by default
  - Not prompt for user input
  - Complete within reasonable time (< 10 minutes typical)

#### Scenario: Report comparison over time

- **WHEN** generating regular assessments
- **THEN** reports MUST:
  - Use consistent format for diff comparison
  - Include assessment timestamp for ordering
  - Be suitable for version control tracking

---

### Requirement: Reference Documentation

The cluster assessment capability SHALL be documented comprehensively in dedicated reference documentation.

#### Scenario: Assessment methodology documentation

- **WHEN** user reads cluster assessment reference
- **THEN** documentation MUST explain:
  - When to use cluster assessment vs health check
  - Four phases: data collection, analysis, report generation, recommendations
  - What data is collected and why
  - How health scoring works

#### Scenario: Usage examples and patterns

- **WHEN** documentation provides usage guidance
- **THEN** it MUST include:
  - Basic script invocation examples
  - Custom output filename example
  - Custom kubeconfig example
  - Automation patterns (cron, CI/CD)
  - Multi-cluster assessment patterns

#### Scenario: Best practices guidance

- **WHEN** documentation covers best practices
- **THEN** it MUST include:
  - Before assessment: prerequisites, permissions, timing
  - During assessment: what not to interrupt
  - After assessment: review process, issue tracking, archival
  - Report management in version control

#### Scenario: Troubleshooting guidance

- **WHEN** documentation covers troubleshooting
- **THEN** it MUST address:
  - Connection failures
  - Incomplete data collection
  - Missing metrics-server
  - Permission issues
  - Report generation errors

---

### Requirement: Integration with Existing Workflows

The cluster assessment workflow SHALL integrate smoothly with existing k8s-troubleshooter workflows without conflicts.

#### Scenario: Complementary to health check

- **WHEN** both health check and assessment are available
- **THEN** documentation MUST:
  - Explain when to use each
  - Show both in workflow menu
  - Clarify non-overlapping use cases

#### Scenario: Cross-referencing to other workflows

- **WHEN** assessment identifies issues
- **THEN** report SHOULD reference specific workflows:
  - Pod failures → `/pod-debug` workflow
  - Network issues → `/network-debug` workflow
  - Storage issues → `/storage-debug` workflow
  - Node issues → `/node-debug` workflow

#### Scenario: No breaking changes

- **WHEN** cluster assessment capability is added
- **THEN** it MUST NOT:
  - Modify existing workflow behavior
  - Change existing script interfaces
  - Alter existing documentation structure beyond additions
  - Require changes to existing automation

---

