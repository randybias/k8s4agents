# Proposal: Add Cluster Assessment Capability

## Problem Statement

The k8s-troubleshooter skill currently provides quick health checks for immediate troubleshooting but lacks comprehensive cluster assessment capabilities needed for:
- Baseline documentation of new or inherited clusters
- Capacity planning and resource utilization analysis
- Audit and compliance documentation
- Quarterly operational reviews
- Handoff documentation when transferring cluster ownership

Quick health checks (workflow 6) provide terminal output for immediate diagnosis but don't generate persistent, shareable reports with prioritized recommendations.

## Proposed Solution

Add a comprehensive cluster assessment workflow that generates detailed markdown reports suitable for documentation, audits, and capacity planning. This complements the existing quick health check rather than replacing it.

### Key Capabilities

1. **Comprehensive Data Collection**
   - Control plane health (API server endpoints: /healthz, /readyz, /livez)
   - Node infrastructure and capacity
   - Workload status across all namespaces
   - Storage infrastructure (PVC/PV, StorageClass)
   - Network configuration and CNI health
   - Recent events and warnings

2. **Analysis and Scoring**
   - Resource overcommitment detection
   - Failed/pending workload identification
   - Node pressure conditions
   - Security posture assessment
   - Health scoring (0-100)

3. **Structured Report Generation**
   - Markdown format for version control and sharing
   - Executive summary with health score
   - Detailed sections for each cluster aspect
   - Prioritized recommendations (High/Medium/Low)
   - Timestamped for historical tracking

4. **Automation Support**
   - Scriptable assessment for CI/CD integration
   - Consistent report format for comparison over time
   - Support for multiple clusters

### Deliverables

1. **Reference Documentation** (`references/cluster-assessment.md`)
   - Complete assessment methodology
   - Comparison to health checks
   - Use cases and best practices
   - Automation patterns

2. **Assessment Script** (`scripts/cluster_assessment.sh`)
   - Automated data collection
   - Report generation
   - CLI with kubeconfig and output options

3. **Skill Workflow** (SKILL.md Workflow 7)
   - `/cluster-assessment` trigger
   - Integration with existing workflows
   - Clear distinction from quick health check

4. **Documentation Updates**
   - README.md updated with assessment features
   - Usage examples and comparisons

## User Impact

### Positive Impact
- Operators gain comprehensive documentation capability
- Reports suitable for audits, capacity planning, and handoffs
- Persistent record of cluster state over time
- Prioritized recommendations guide improvement efforts

### No Breaking Changes
- Existing workflows remain unchanged
- Complements rather than replaces quick health check
- New optional capability

## Alternatives Considered

1. **Extend existing health check script**
   - Rejected: Different use cases (quick vs comprehensive) warrant separate tools

2. **Use existing tools (kube-bench, Popeye)**
   - These tools focus on security/best-practices scanning
   - Assessment provides broader operational context
   - Custom script integrates with skill workflows

3. **Manual assessment process**
   - Rejected: Inconsistent, time-consuming, error-prone
   - Automation ensures completeness

## Implementation Scope

This is a **MEDIUM** scope change:
- Adds one new workflow (cluster assessment)
- Creates new reference documentation
- Adds new script with comprehensive logic
- Updates existing documentation
- No changes to existing workflows or APIs

## Dependencies

- Existing k8s-troubleshooter skill structure
- kubectl access (read-only cluster-wide)
- Optional: metrics-server for resource usage data
- jq for JSON processing in script

## Success Criteria

1. Assessment script generates valid markdown reports
2. Reports include all documented sections
3. Health scoring is accurate and useful
4. Recommendations are prioritized and actionable
5. Documentation clearly distinguishes from health check
6. Script validates successfully with shellcheck
7. OpenSpec validation passes with --strict flag
