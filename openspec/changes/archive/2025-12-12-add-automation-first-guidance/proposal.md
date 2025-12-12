# Change: Add Automation-First Guidance to k8s-troubleshooter Skill

## Why

When Claude Code invokes the k8s-troubleshooter skill, it receives documentation that describes both manual workflows (kubectl commands) and automation scripts. However, the skill presents these as equivalent options without clear prioritization. This leads to Claude following the verbose manual workflows even when production-ready automation scripts exist.

**Root Cause**: The skill is structured as a reference/knowledge skill that provides expert workflows. Claude reads the documentation and chooses to follow the detailed manual steps rather than recognizing that automation should be preferred. The skill documentation does not make automation the default recommendation.

**Observed Failure**: When asked to perform a cluster assessment, Claude:
1. Invoked the Skill tool with "k8s-troubleshooter"
2. Read the documentation showing both manual workflow phases and script mentions
3. Executed ~20+ individual kubectl commands manually
4. Never ran `./scripts/cluster_assessment.sh` despite it being documented

## What Changes

1. **Add prominent "Automation First" section** at the top of SKILL.md that:
   - Clearly states scripts should be used before manual workflows
   - Provides a quick reference table mapping tasks to scripts
   - Includes ready-to-copy script invocation commands

2. **Restructure workflow sections** to lead with script usage:
   - Add "AUTOMATED SCRIPT AVAILABLE" callout at the start of each workflow that has automation
   - Move script invocation examples before manual workflow steps
   - Make manual steps explicitly labeled as "fallback" or "for understanding"

3. **Add new spec requirement** for Automation-First Behavior that:
   - Requires scripts to be recommended before manual workflows
   - Requires script existence checks before falling back to manual
   - Ensures consistent automation-first pattern across all workflows

## Impact

- **Affected specs**: `k8s-troubleshooter`
- **Affected files**:
  - `~/.claude/skills/k8s-troubleshooter/SKILL.md` (main skill documentation)
  - `~/.claude/skills/k8s-troubleshooter/README.md` (external documentation)
- **Behavior change**: Claude will prioritize running automation scripts over manual kubectl workflows
- **No breaking changes**: Manual workflows remain available as fallback
