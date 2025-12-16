# Lint Fail Chart.yaml Test Chart

## Purpose
This chart tests detection of invalid Chart.yaml files during linting.

## Failure Mechanism
- Chart.yaml is missing the required "version" field
- This violates Helm chart specification
- Lint should fail immediately

## Expected Behavior
- `helm lint` command fails with error
- Error message indicates missing "version" field in Chart.yaml
- Cannot proceed with installation
- Clear validation error before deployment attempt

## Test Usage
```bash
helm lint ./lint-fail-chart-yaml
```

## Expected Error
```
Error: validation: chart.metadata.version is required
```

## Cleanup
No cleanup needed - chart cannot be deployed.
