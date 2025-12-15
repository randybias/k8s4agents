## MODIFIED Requirements

### Requirement: Skill Metadata and Triggering

The skill SHALL provide YAML frontmatter with `name` and `description` fields that accurately describe when to use the skill for Kubernetes troubleshooting tasks.

#### Scenario: Skill triggers on troubleshooting request
- **WHEN** user asks "why is my pod not starting" or "debug my kubernetes deployment"
- **THEN** the skill MUST be triggered based on frontmatter description matching

#### Scenario: Skill provides comprehensive description
- **WHEN** skill metadata is loaded
- **THEN** description MUST include troubleshooting contexts: pods, services, networking, storage, helm, cluster health

#### Scenario: Slash commands exist as command files
- **WHEN** user invokes slash commands (e.g., `/k8s-pod-debug`, `/k8s-svc-debug`, `/k8s-health-check`)
- **THEN** skill MUST have corresponding `.md` files in `commands/` directory that define the command behavior

#### Scenario: Slash commands use k8s- prefix
- **WHEN** skill provides slash commands
- **THEN** all command names MUST be prefixed with `k8s-` to namespace them clearly

---

### Requirement: Automation-First Behavior

The skill SHALL prioritize automation scripts over manual command sequences when scripts are available for the requested task.

#### Scenario: Script paths are relative
- **WHEN** documenting script invocation
- **THEN** paths MUST be relative to the skill directory (e.g., `./scripts/cluster_health_check.sh`)
- **AND** paths MUST NOT contain hardcoded user home directories or absolute paths

#### Scenario: Script recommended before manual workflow
- **WHEN** a workflow has an associated automation script in `scripts/` directory
- **THEN** the skill documentation MUST present the script invocation command before any manual kubectl commands
- **AND** the script command MUST include relative path and common parameters

#### Scenario: Automation-first section visible at top
- **WHEN** the skill is invoked
- **THEN** an "Automation First" section MUST appear within the first 100 lines of SKILL.md
- **AND** the section MUST include a table mapping tasks to their automation scripts

#### Scenario: Manual workflows labeled as fallback
- **WHEN** a workflow has both script and manual options
- **THEN** the manual workflow section MUST be explicitly labeled as "Fallback" or "For Understanding"
- **AND** the script option MUST be labeled as the primary/recommended approach

#### Scenario: Script invocation includes working examples
- **WHEN** documenting a script
- **THEN** the documentation MUST include at least one complete, copy-paste ready invocation example
- **AND** the example MUST use relative paths

---

## ADDED Requirements

### Requirement: Slash Command Configuration

The skill SHALL provide working slash command files in a `commands/` directory that can be invoked by Claude Code.

#### Scenario: Pod debugging command
- **WHEN** user invokes `/k8s-pod-debug`
- **THEN** skill MUST have `commands/k8s-pod-debug.md` that triggers pod troubleshooting workflow

#### Scenario: Service debugging command
- **WHEN** user invokes `/k8s-svc-debug`
- **THEN** skill MUST have `commands/k8s-svc-debug.md` that triggers service connectivity workflow

#### Scenario: Storage debugging command
- **WHEN** user invokes `/k8s-storage-debug`
- **THEN** skill MUST have `commands/k8s-storage-debug.md` that triggers storage troubleshooting workflow

#### Scenario: Network debugging command
- **WHEN** user invokes `/k8s-network-debug`
- **THEN** skill MUST have `commands/k8s-network-debug.md` that triggers network policy debugging workflow

#### Scenario: Node debugging command
- **WHEN** user invokes `/k8s-node-debug`
- **THEN** skill MUST have `commands/k8s-node-debug.md` that triggers node health workflow

#### Scenario: Helm debugging command
- **WHEN** user invokes `/k8s-helm-debug`
- **THEN** skill MUST have `commands/k8s-helm-debug.md` that triggers Helm troubleshooting workflow

#### Scenario: Health check command
- **WHEN** user invokes `/k8s-health-check`
- **THEN** skill MUST have `commands/k8s-health-check.md` that triggers cluster health check workflow

#### Scenario: Cluster assessment command
- **WHEN** user invokes `/k8s-cluster-assessment`
- **THEN** skill MUST have `commands/k8s-cluster-assessment.md` that triggers comprehensive assessment workflow

---

### Requirement: Clean User Documentation

The skill documentation SHALL focus on usage and capabilities, not internal development tracking.

#### Scenario: No development status in README
- **WHEN** README.md is rendered
- **THEN** file MUST NOT contain task completion percentages, checkbox lists, or "Development Status" sections

#### Scenario: No line count claims
- **WHEN** README.md references other files
- **THEN** file MUST NOT include specific line counts that become stale

#### Scenario: README focuses on user value
- **WHEN** user reads README.md
- **THEN** content MUST focus on: what the skill does, how to use it, available commands/scripts
