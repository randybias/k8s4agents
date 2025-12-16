# OS-002: Database Migration Failures Test Chart

## Purpose

This chart tests detection when a database migration hook fails.

## Failure Mechanism

The pre-install migration hook attempts to connect to a non-existent database (`nonexistent-database.example.com:5432`), causing the connection to fail and the migration hook to exit with code 1.

## Usage

```bash
# Deploy chart with failing database migration hook
helm install test-db-migration ./db-migration-fail -n helm-test-hooks

# Wait for hook to fail
sleep 30

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-db-migration helm-test-hooks
```

## Expected Behavior

- Release stuck in pending-install
- Pre-install migration hook fails
- Hook logs show database connection errors
- Main app not deployed
- Script identifies migration hook failure

## Validation

```bash
# Verify migration hook failed
kubectl get jobs -n helm-test-hooks -l "helm.sh/hook=pre-install,job=migration"

# Check migration logs
kubectl logs -n helm-test-hooks -l "helm.sh/hook=pre-install,job=migration"

# Verify app not deployed
kubectl get pods -n helm-test-hooks -l app=test-app | grep -i running || echo "App not running"
```

## Cleanup

```bash
kubectl delete jobs -n helm-test-hooks -l "helm.sh/hook=pre-install"
helm uninstall test-db-migration -n helm-test-hooks
kubectl delete pods -n helm-test-hooks --all
```

## Notes

This is a common real-world failure pattern where database migrations fail due to connectivity issues, missing schemas, or migration script errors.
