# Claude Skills

This directory contains Claude Skills that enhance AI agent capabilities for specific domains and workflows.

## Available Skills

### k8s-troubleshooter

Comprehensive Kubernetes troubleshooting skill providing:
- Systematic diagnostic workflows for pods, services, storage, networking
- Production-safe kubectl command patterns
- Incident response playbooks (CrashLoopBackOff, OOMKilled, DNS failures, etc.)
- Helm debugging workflows
- CNI (Calico) and CSI storage troubleshooting
- MCP server integration guidance

**Status:** Production-ready, tested on kind and k0s clusters
**Docs:** [skills/k8s-troubleshooter/README.md](k8s-troubleshooter/README.md)

## Skill Structure

Each skill follows this standard structure:

```
skill-name/
├── SKILL.md           # Core skill instructions (required)
├── LICENSE.txt        # License information
├── README.md          # User documentation
├── TESTING.md         # Testing documentation (optional)
├── references/        # Detailed reference docs (progressive disclosure)
└── scripts/          # Executable diagnostic/helper scripts
```

## Using Skills

### With Claude Code

Link skills to your Claude Code skills directory:

```bash
ln -s $(pwd)/k8s-troubleshooter ~/.claude/skills/k8s-troubleshooter
```

### With Claude Desktop

Copy skills to your configured skills directory:

```bash
cp -r k8s-troubleshooter /path/to/your/claude/skills/
```

## Creating New Skills

Use the templates in `skill-templates/basic/`:

```bash
cp -r ../skill-templates/basic new-skill-name
cd new-skill-name
# Edit SKILL.md with your content
```

## Guidelines

### Skill Design Principles

1. **Progressive Disclosure** - Keep SKILL.md under 500 lines, use references/ for deep dives
2. **Production-Safe** - Default to read-only commands, clearly mark state-changing operations
3. **Systematic Workflows** - Guide from symptoms to root causes through structured steps
4. **Context Awareness** - Adapt to different environments (cloud, on-prem, distributions)

### SKILL.md Format

```yaml
---
name: skill-name
description: Clear description of when and why to use this skill
---

# Skill Name

Instructions that Claude follows when this skill is active...
```

### Script Requirements

- Use `#!/usr/bin/env bash` or `#!/usr/bin/env python3` shebangs
- Make scripts executable (`chmod +x`)
- Include clear usage comments
- Fail gracefully with helpful error messages
- Default to read-only operations

## Testing Skills

Test skills against real environments:

1. Trigger the skill with relevant prompts
2. Verify Claude uses appropriate workflows
3. Validate generated commands are correct and safe
4. Test scripts execute without errors
5. Check reference files load properly

## Packaging Skills

Use the project Makefile to build distributable packages:

```bash
# From project root
make package-skill SKILL=skill-name
```

Packages are created in `dist/` (gitignored).

## Resources

- [Claude Skills Documentation](https://docs.claude.com/en/docs/claude-code/skills)
- [Official Anthropic Skills](https://github.com/anthropics/skills)
- [Skill Creation Guide](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills)
