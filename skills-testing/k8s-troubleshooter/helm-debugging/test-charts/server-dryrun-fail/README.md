# DR-002: Server-Side Dry-Run Failures Test Chart

## Purpose

This chart tests detection of issues caught only by server-side validation that pass client-side checks.

## Failure Mechanism

Requests extremely high resource limits (999999 Gi memory, 999999 CPU cores) that are syntactically valid but impossible to schedule. Server-side admission controllers may reject this.

## Usage

```bash
# Client-side dry-run succeeds (valid YAML)
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run

# Server-side dry-run may fail
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run=server

# Run debug script
/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh \
  test-server-dryrun helm-test-dryrun \
  --chart ./server-dryrun-fail --run-dry-run
```

## Expected Behavior

- Client-side dry-run passes
- Server-side dry-run may fail or warn
- Scheduler would reject pod as unschedulable
- Resource limit validation happens server-side

## Validation

```bash
# Client succeeds
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run 2>&1 | tail -5

# Server may reject or warn
helm install test-server-dryrun ./server-dryrun-fail -n helm-test-dryrun --dry-run=server 2>&1 | grep -i "error\|warn"
```

## Notes

Behavior depends on cluster configuration. Some clusters may accept this but the pod would be unschedulable.
