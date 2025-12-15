# Tasks: Fix k8s-troubleshooter Skill

## 1. Create Slash Commands

- [ ] 1.1 Create `commands/` directory in skill
- [ ] 1.2 Create `k8s-pod-debug.md` slash command
- [ ] 1.3 Create `k8s-svc-debug.md` slash command
- [ ] 1.4 Create `k8s-storage-debug.md` slash command
- [ ] 1.5 Create `k8s-network-debug.md` slash command
- [ ] 1.6 Create `k8s-node-debug.md` slash command
- [ ] 1.7 Create `k8s-helm-debug.md` slash command
- [ ] 1.8 Create `k8s-health-check.md` slash command (replaces /full-diag)
- [ ] 1.9 Create `k8s-cluster-assessment.md` slash command

## 2. Fix Hardcoded Paths

- [ ] 2.1 Update SKILL.md to use relative script paths (e.g., `./scripts/cluster_health_check.sh`)
- [ ] 2.2 Update script task-to-invocation table to remove absolute paths

## 3. Clean Up Documentation

- [ ] 3.1 Remove "Development Status" section from README.md
- [ ] 3.2 Remove line count claims from README.md
- [ ] 3.3 Update "Slash Commands" section with correct `k8s-` prefixed names
- [ ] 3.4 Simplify README.md to focus on usage, not internals
- [ ] 3.5 Update SKILL.md "Quick Start: Slash Commands" section with correct names

## 4. Remove Artifacts

- [ ] 4.1 Delete `scripts/k8s-troubleshooter-skill.tar.gz` (broken 29-byte file)
- [ ] 4.2 Delete `TESTING.md` (internal development doc)

## 5. Validation

- [ ] 5.1 Verify all slash commands exist and are properly formatted
- [ ] 5.2 Verify no remaining hardcoded `~/.claude/skills/` paths in SKILL.md
- [ ] 5.3 Verify README.md has no development/task tracking content
