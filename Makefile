.PHONY: help clean build build-all list-skills package-skill install-skill uninstall-skill

# Configuration
SKILLS_DIR := skills
DIST_DIR := dist
TEMPLATES_DIR := skill-templates
CLAUDE_SKILLS_DIR := $(HOME)/.claude/skills

# Get all skill directories
SKILLS := $(shell find $(SKILLS_DIR) -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

help:
	@echo "Claude Skills Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make list-skills                 List all available skills"
	@echo "  make install-skill SKILL=<name>  Install skill to ~/.claude/skills/"
	@echo "  make uninstall-skill SKILL=<name> Remove skill from ~/.claude/skills/"
	@echo "  make build                       Build all skill packages"
	@echo "  make package-skill SKILL=<name>  Build specific skill package"
	@echo "  make clean                       Remove all built packages"
	@echo ""
	@echo "Examples:"
	@echo "  make install-skill SKILL=k8s-troubleshooter"
	@echo "  make uninstall-skill SKILL=k8s-troubleshooter"
	@echo "  make package-skill SKILL=k8s-troubleshooter"
	@echo "  make build"
	@echo ""

list-skills:
	@echo "Available skills:"
	@for skill in $(SKILLS); do \
		echo "  - $$skill"; \
	done

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(DIST_DIR)
	@echo "✓ Clean complete"

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

# Build a specific skill package
package-skill: $(DIST_DIR)
	@if [ -z "$(SKILL)" ]; then \
		echo "Error: SKILL parameter required"; \
		echo "Usage: make package-skill SKILL=<skill-name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(SKILLS_DIR)/$(SKILL)" ]; then \
		echo "Error: Skill '$(SKILL)' not found in $(SKILLS_DIR)/"; \
		exit 1; \
	fi
	@echo "Packaging skill: $(SKILL)"
	@cd $(SKILLS_DIR) && tar -czf ../$(DIST_DIR)/$(SKILL)-skill.tar.gz $(SKILL)/
	@echo "✓ Package created: $(DIST_DIR)/$(SKILL)-skill.tar.gz"
	@ls -lh $(DIST_DIR)/$(SKILL)-skill.tar.gz

# Build all skills
build: $(DIST_DIR)
	@echo "Building all skill packages..."
	@for skill in $(SKILLS); do \
		echo "Packaging: $$skill"; \
		cd $(SKILLS_DIR) && tar -czf ../$(DIST_DIR)/$$skill-skill.tar.gz $$skill/; \
	done
	@echo ""
	@echo "✓ Build complete. Packages created:"
	@ls -lh $(DIST_DIR)/*.tar.gz

# Alias for build
build-all: build

# Install a skill to ~/.claude/skills/
install-skill:
	@if [ -z "$(SKILL)" ]; then \
		echo "Error: SKILL parameter required"; \
		echo "Usage: make install-skill SKILL=<skill-name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(SKILLS_DIR)/$(SKILL)" ]; then \
		echo "Error: Skill '$(SKILL)' not found in $(SKILLS_DIR)/"; \
		exit 1; \
	fi
	@echo "Installing skill: $(SKILL)"
	@mkdir -p $(CLAUDE_SKILLS_DIR)
	@rsync -a --delete $(SKILLS_DIR)/$(SKILL)/ $(CLAUDE_SKILLS_DIR)/$(SKILL)/
	@echo "✓ Skill installed: $(CLAUDE_SKILLS_DIR)/$(SKILL)"

# Uninstall a skill from ~/.claude/skills/
uninstall-skill:
	@if [ -z "$(SKILL)" ]; then \
		echo "Error: SKILL parameter required"; \
		echo "Usage: make uninstall-skill SKILL=<skill-name>"; \
		exit 1; \
	fi
	@if [ -d "$(CLAUDE_SKILLS_DIR)/$(SKILL)" ]; then \
		echo "Uninstalling skill: $(SKILL)"; \
		rm -rf $(CLAUDE_SKILLS_DIR)/$(SKILL); \
		echo "✓ Skill uninstalled"; \
	else \
		echo "Skill '$(SKILL)' is not installed"; \
	fi
