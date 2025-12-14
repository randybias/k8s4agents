# Spec Delta: cluster-assessment

## MODIFIED Requirements

### Requirement: Analysis and Health Scoring

The cluster assessment workflow SHALL analyze collected data and compute a health score with identified issues.

#### Scenario: Container state failure detection

- **WHEN** assessment analyzes pod container statuses
- **THEN** it MUST detect pods with waiting container states:
  - CrashLoopBackOff
  - ImagePullBackOff
  - ErrImagePull
  - CreateContainerError
- **AND** classify these as unhealthy pods

#### Scenario: High restart count detection

- **WHEN** assessment analyzes pod container statuses
- **THEN** it MUST identify pods with restart count > 5
- **AND** classify these as unhealthy pods

#### Scenario: Failure detection

- **WHEN** assessment analyzes pod status
- **THEN** it MUST identify:
  - Pods in Failed phase with reasons
  - Pods with container waiting states (CrashLoopBackOff, ImagePullBackOff, etc.)
  - Pods with high restart counts (>5)
  - Pending pods with scheduling reasons

#### Scenario: Health score computation

- **WHEN** assessment computes overall health score
- **THEN** it MUST:
  - Start with base score of 100
  - Apply deductions for issues (failed pods, unhealthy pods, node pressure, overcommitment, missing monitoring, etc.)
  - Provide score ranges interpretation:
    - 90-100: Excellent
    - 75-89: Good
    - 60-74: Fair
    - Below 60: Poor

## ADDED Requirements

### Requirement: Unhealthy Pod Reporting

The cluster assessment workflow SHALL detect and report pods in problematic states beyond Failed phase.

#### Scenario: Unhealthy pod data collection

- **WHEN** assessment collects workload data
- **THEN** it MUST query container statuses for all pods
- **AND** extract:
  - Container waiting states and reasons
  - Container restart counts
  - Container ready status

#### Scenario: Unhealthy pod identification

- **WHEN** assessment analyzes container statuses
- **THEN** it MUST classify a pod as unhealthy if:
  - Any container has waiting state with reason: CrashLoopBackOff, ImagePullBackOff, ErrImagePull, or CreateContainerError
  - Any container has restart count > 5
  - Pod is not in Failed phase (to avoid duplicate counting)

#### Scenario: Unhealthy pod report section

- **WHEN** report includes workload status
- **THEN** it MUST include "Unhealthy Pods" subsection
- **AND** for each unhealthy pod display:
  - Namespace
  - Pod name
  - Container status (CrashLoopBackOff, ImagePullBackOff, etc.)
  - Restart count
  - Reason/message
- **OR** show "No unhealthy pods detected" if none found

#### Scenario: Health status reflects unhealthy pods

- **WHEN** assessment determines overall health status
- **THEN** if any unhealthy pods are detected:
  - Overall health MUST be "DEGRADED" or "CRITICAL" (not "HEALTHY")
- **AND** executive summary MUST mention count of unhealthy pods

#### Scenario: Recommendations for unhealthy pods

- **WHEN** unhealthy pods are detected
- **THEN** recommendations MUST include:
  - **High Priority** for CrashLoopBackOff pods: "Investigate pod logs with: kubectl logs <pod> -n <namespace>"
  - **High Priority** for ImagePullBackOff pods: "Verify image exists and pull secrets with: kubectl describe pod <pod> -n <namespace>"
  - **Medium Priority** for high restart counts: "Review pod stability and resource limits"
