# CV-003: Template Rendering Failures Test Chart

## Purpose

This chart tests detection of template rendering errors caused by accessing undefined values.

## Failure Mechanism

The deployment template references `{{ .Values.version.major }}` which doesn't exist in values.yaml, causing a nil pointer error during template rendering.

## Usage

```bash
# Template rendering will fail
helm template test-template-fail ./template-fail

# Validation catches the issue
helm template test-template-fail ./template-fail --validate
```

## Expected Behavior

- Template rendering fails
- Error shows "nil pointer" or "undefined variable"
- Points to specific template file and line
- Validation catches the issue

## Validation

```bash
# Verify template error
helm template test-template-fail ./template-fail 2>&1 | grep -i "nil\|undefined\|error"

# Check templates for issues
grep -r "\.Values\." ./template-fail/templates/
```
