# k8s4agents

A collection of Claude Skills for Kubernetes and cloud infrastructure operations, designed to enhance AI agent capabilities in DevOps, SRE, and platform engineering workflows.

## Overview

This repository provides production-ready Claude Skills that encode expert knowledge for:
- Kubernetes troubleshooting and operations
- Cloud infrastructure debugging
- Infrastructure as Code workflows
- Platform engineering best practices

## Available Skills

### Kubernetes Operations

- **[k8s-troubleshooter](skills/k8s-troubleshooter/)** - Comprehensive Kubernetes troubleshooting workflows
  - Pod, service, storage, and networking diagnostics
  - Helm debugging and CNI troubleshooting
  - Production-safe command patterns
  - Incident response playbooks

## Getting Started

### Using Skills with Claude Code

```bash
# Clone the repository
git clone https://github.com/yourusername/k8s4agents.git

# Link a skill to your Claude Code skills directory
ln -s $(pwd)/skills/k8s-troubleshooter ~/.claude/skills/k8s-troubleshooter
```

### Using Skills with Claude Desktop

Copy skills to your configured skills directory:

```bash
cp -r skills/k8s-troubleshooter /path/to/your/claude/skills/
```

## Building Packages

Use the included Makefile to build distributable packages:

```bash
# Build all skills
make build

# Build a specific skill
make package-skill SKILL=k8s-troubleshooter

# List available skills
make list-skills

# Clean build artifacts
make clean
```

Packages are created in the `dist/` directory (gitignored).

## Repository Structure

```
k8s4agents/
├── skills/              # All Claude Skills
│   └── k8s-troubleshooter/
├── skill-templates/     # Templates for creating new skills
│   └── basic/
├── docs/               # Project documentation
├── openspec/           # OpenSpec change specifications
├── Makefile            # Build system
└── README.md
```

## Creating a New Skill

1. Copy the template:
   ```bash
   cp -r skill-templates/basic skills/my-new-skill
   ```

2. Edit `SKILL.md` with your skill content

3. Add scripts and references as needed

4. Test with Claude Code or Claude Desktop

5. Build package:
   ```bash
   make package-skill SKILL=my-new-skill
   ```

## Development

### OpenSpec Workflow

This repository uses OpenSpec for managing changes. See `openspec/` directory for specifications.

### Testing Skills

Skills should be tested against real environments:
- Kubernetes clusters for k8s-* skills
- Cloud provider accounts for cloud-* skills
- Validate scripts execute without errors

## Contributing

Contributions are welcome! Please:

1. Follow the skill template structure
2. Include comprehensive documentation
3. Test against production-like environments
4. Follow production-safe command patterns (read-only by default)

## License

See individual skill LICENSE.txt files for licensing information.

## Credits

Built with patterns from:
- [Anthropic Official Skills](https://github.com/anthropics/skills)
- [Claude Skills Documentation](https://docs.claude.com/en/docs/claude-code/skills)
- Community Claude Skills repositories

---

**Note:** These skills are designed to assist with operations but should not replace human judgment, especially in production environments. Always review suggested commands before execution.
