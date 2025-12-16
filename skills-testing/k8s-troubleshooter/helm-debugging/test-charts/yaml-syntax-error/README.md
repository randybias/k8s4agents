# CV-006: YAML Syntax Errors Test Chart

## Purpose

This chart tests detection of invalid YAML syntax in values or templates.

## Failure Mechanism

The values.yaml file contains a TAB character on line 5 (before `pullPolicy`), which is invalid in YAML. YAML requires spaces for indentation, not tabs.

## Usage

```bash
# Lint will fail immediately
helm lint ./yaml-syntax-error

# Template rendering will fail
helm template test-yaml-error ./yaml-syntax-error
```

## Expected Behavior

- Lint fails immediately
- YAML parser error reported
- Points to file and line number
- Describes syntax issue (tabs vs spaces)

## Validation

```bash
# Verify YAML syntax error
helm lint ./yaml-syntax-error 2>&1 | grep -i "yaml\|syntax\|parse\|tab"

# Check problematic file
cat -A ./yaml-syntax-error/values.yaml | grep -n "^I"
```

## Notes

The tab character is intentionally placed before `pullPolicy` in values.yaml to trigger YAML parsing errors.
