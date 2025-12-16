# CV-002: Lint Failures - Syntax Errors Test Chart

## Purpose

This chart tests detection of YAML syntax errors in templates.

## Failure Mechanism

The deployment template has incorrect indentation on line 10 (`matchLabels` is missing proper indentation), causing YAML syntax errors.

## Usage

```bash
# Lint will fail
helm lint ./lint-fail-syntax

# Template rendering will fail
helm template test-syntax ./lint-fail-syntax
```

## Expected Behavior

- Lint reports YAML syntax errors
- Invalid indentation detected
- Template rendering fails
- Clear error messages pointing to problematic lines

## Validation

```bash
# Verify syntax error reported
helm lint ./lint-fail-syntax 2>&1 | grep -i "syntax\|indent\|yaml"

# Template should fail
helm template test-syntax ./lint-fail-syntax 2>&1 | grep -i error
```
