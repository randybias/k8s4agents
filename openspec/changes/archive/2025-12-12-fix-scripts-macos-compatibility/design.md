# Design: Fix Scripts macOS Compatibility

## Context

The k8s-troubleshooter skill scripts must run on:
- **macOS** (developer laptops) - uses BSD userland tools
- **Linux/Debian** (CI/CD, servers) - uses GNU userland tools

The primary incompatibility is in `cluster_assessment.sh` which uses `sed -i.bak` with template substitution. BSD sed handles in-place editing and multiline patterns differently than GNU sed.

## Goals / Non-Goals

**Goals:**
- All scripts run without modification on macOS and Linux
- No requirement for users to install GNU coreutils
- Maintain readability and maintainability of scripts

**Non-Goals:**
- Support for Windows (WSL is a Linux environment)
- Support for ancient shell versions (target bash 3.2+)
- Performance optimization (diagnostic scripts don't need to be fast)

## Decisions

### Decision 1: Replace sed template substitution with inline generation

**What:** Rewrite `cluster_assessment.sh` to generate markdown content directly using heredocs and printf, instead of writing a template file and doing sed replacements.

**Why:**
- Heredocs with variable expansion are fully POSIX-compliant
- No platform differences in behavior
- Simpler code (no template file, no sed calls)
- Easier to read and maintain

**Alternatives considered:**
1. **Use `gsed` (GNU sed)** - Requires users to `brew install gnu-sed`, unacceptable dependency
2. **Use `perl` instead of `sed`** - More portable but adds perl dependency
3. **Use `awk` for replacements** - More complex, harder to read
4. **Detect OS and use different sed syntax** - Fragile, doubles code paths

### Decision 2: Known BSD/GNU differences to avoid

| Construct | GNU | BSD | Solution |
|-----------|-----|-----|----------|
| `sed -i ''` | Works | Required | Avoid sed -i entirely |
| `sed -i.bak` | Works | Works differently | Avoid sed -i entirely |
| `grep -P` | Perl regex | Not available | Use `grep -E` (extended regex) |
| `date +%s` | Unix timestamp | Works | OK to use |
| `wc -l` | Returns ` 123` | Returns `     123` | Pipe through `tr -d ' '` |
| `readarray` | Built-in | Not in bash 3.2 | Use `while read` loop |

### Decision 3: Script structure pattern

Each script should follow this portable pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail

# POSIX-compliant functions
generate_section() {
    cat << EOF
## Section Header

Content with $variable expansion
EOF
}

# Main report generation
main() {
    {
        generate_header
        generate_section1
        generate_section2
    } > "$OUTPUT_FILE"
}
```

## Risks / Trade-offs

- **Risk:** Heredocs with variable expansion are harder to template
  - **Mitigation:** Use functions for each section, keeping logic close to output

- **Risk:** Some edge cases in bash 3.2 (macOS default)
  - **Mitigation:** Test on macOS with system bash, avoid bash 4+ features

## Migration Plan

1. Fix `cluster_assessment.sh` first (the broken script)
2. Audit remaining scripts
3. Test on macOS
4. Test on Debian
5. No backwards compatibility concerns - scripts are self-contained

## Open Questions

- None - the approach is straightforward
