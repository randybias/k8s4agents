# Change: Fix k8s-troubleshooter Skill

## Why

The k8s-troubleshooter skill documentation claims features that don't work:
1. Slash commands (`/pod-debug`, `/svc-debug`, etc.) are documented but don't exist
2. Script paths are hardcoded to `~/.claude/skills/k8s-troubleshooter/` which is fragile
3. Development status/task tracking clutters user-facing docs

## What Changes

- **Create actual slash commands** with `k8s-` prefix (e.g., `/k8s-pod-debug`) in a `commands/` directory
- **Remove hardcoded paths** - use relative paths or variables that work regardless of install location
- **Remove development status sections** from README.md - keep docs clean and user-focused
- **Remove broken tar.gz artifact** from scripts directory
- **Simplify documentation** - less is more for a proof of concept

## Impact

- Affected specs: `k8s-troubleshooter`
- Affected files:
  - `skills/k8s-troubleshooter/README.md` - remove dev status, fix command docs
  - `skills/k8s-troubleshooter/SKILL.md` - remove hardcoded paths, update command references
  - `skills/k8s-troubleshooter/commands/*.md` - **NEW** - actual slash command files
  - `skills/k8s-troubleshooter/scripts/k8s-troubleshooter-skill.tar.gz` - **DELETE**
  - `skills/k8s-troubleshooter/TESTING.md` - **DELETE** - internal dev doc
