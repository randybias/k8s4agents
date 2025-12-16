# CV-004: Missing Required Values Test Chart

## Purpose

This chart tests detection when required values are not provided.

## Failure Mechanism

The deployment template uses `required` function to enforce that `databaseUrl` must be provided. If not set, template rendering fails with a clear error message.

## Usage

```bash
# Attempt to render without required values (will fail)
helm template test-missing-values ./missing-required-values

# Attempt installation (will fail)
helm install test-missing-values ./missing-required-values -n helm-test-validation --dry-run

# Provide required value (will succeed)
helm template test-missing-values ./missing-required-values --set databaseUrl=postgres://localhost:5432/db
```

## Expected Behavior

- Template rendering fails
- Error indicates missing required value "databaseUrl"
- Shows which value is required
- Provides helpful error message

## Validation

```bash
# Verify error about missing values
helm template test-missing-values ./missing-required-values 2>&1 | grep -i "required\|missing\|databaseUrl"

# Check what values are needed
cat ./missing-required-values/templates/deployment.yaml | grep required
```
