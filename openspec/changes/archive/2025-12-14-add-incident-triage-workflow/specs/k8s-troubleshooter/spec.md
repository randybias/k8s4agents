# Spec Delta: k8s-troubleshooter

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Production-Safe Command Patterns

The skill SHALL provide kubectl commands that are read-only by default and clearly separate diagnostic commands from remediation actions.

#### Scenario: Verbose readiness endpoint

- **WHEN** skill checks API server health
- **THEN** it MUST use `/readyz?verbose` for human-readable component status
- **AND** MAY fall back to `/healthz` for basic health only

### Requirement: Automation-First Behavior

The skill SHALL prioritize automation scripts over manual command sequences when scripts are available for the requested task.

#### Scenario: Incident triage as entry point

- **WHEN** user reports production incident
- **THEN** skill MUST recommend `incident_triage.sh` before domain-specific scripts
- **AND** domain-specific scripts (pod_diagnostics, network_debug, etc.) MUST be positioned as "deep dive" after triage
