# Change: Enhance Pod Failure Detection in Cluster Assessment

## Why

The cluster assessment script currently only detects pods in `Failed` phase, but misses common failure states like CrashLoopBackOff and ImagePullBackOff. When a pod is crashing repeatedly:

1. The pod phase is `Running` (not `Failed`)
2. Container status shows `waiting.reason: CrashLoopBackOff`
3. Restart count is high (6+ restarts)
4. Container ready state is `false`

This causes assessments to report "Overall Health: HEALTHY" when pods are actively crashing, undermining trust in the tool.

**Real example from testing:**
- Pod `crash-test` in CrashLoopBackOff with 6 restarts
- Report showed: "Failed: 0", "Overall Health: HEALTHY"
- Only visible in warning events, not in pod status analysis

## What Changes

Enhance the `get_pod_counts()` and related functions in `cluster_assessment.sh` to:

1. **Add container state analysis** - detect CrashLoopBackOff, ImagePullBackOff, ErrImagePull, CreateContainerError
2. **Add restart count analysis** - flag pods with high restart counts (>5 in recent period)
3. **Add unhealthy pod section** - dedicated report section showing problematic pods with reasons
4. **Update health scoring** - factor unhealthy pods into overall health determination
5. **Update recommendations** - generate specific actions for detected unhealthy pods

## Impact

- Affected specs: `cluster-assessment`
- Affected files:
  - `skills/k8s-troubleshooter/scripts/cluster_assessment.sh` - add unhealthy pod detection
  - `openspec/specs/cluster-assessment/spec.md` - enhance failure detection requirement

Breaking changes: None (only adds new detection, existing behavior unchanged)
