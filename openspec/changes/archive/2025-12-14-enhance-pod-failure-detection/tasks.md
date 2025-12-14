# Tasks for enhance-pod-failure-detection

## Implementation Tasks

- [x] 1. **Add `get_unhealthy_pods()` function to cluster_assessment.sh**
   - Query all pods with container status details
   - Detect waiting states: CrashLoopBackOff, ImagePullBackOff, ErrImagePull, CreateContainerError
   - Detect high restart counts (>5)
   - Return formatted list with namespace, pod name, status, restart count, reason

- [x] 2. **Update `get_pod_counts()` function**
   - Add unhealthy pod count to returned data
   - Format: `total|running|pending|failed|unhealthy`

- [x] 3. **Update report generation in `generate_report()`**
   - Call `get_unhealthy_pods()` during data collection
   - Add "Unhealthy Pods" subsection under "4. Workload Status"
   - Display unhealthy pods with details (namespace, name, status, restarts, reason)

- [x] 4. **Update health determination logic**
   - Modify `overall_health` calculation to consider unhealthy pods
   - Set to "DEGRADED" if any unhealthy pods detected

- [x] 5. **Update recommendations in `generate_recommendations()`**
   - Add high-priority recommendation for pods in CrashLoopBackOff
   - Add medium-priority recommendation for pods with high restart counts
   - Include specific kubectl commands to investigate

- [x] 6. **Update cluster-assessment spec**
   - Enhance "Failure detection" scenario with container state analysis
   - Add requirement scenarios for CrashLoopBackOff and restart count detection

## Validation Tasks

- [x] 7. **Test with CrashLoopBackOff pod**
   - Create test pod that crashes immediately
   - Run cluster assessment
   - Verify unhealthy pods section shows the pod with correct reason
   - Verify overall health is "DEGRADED"

- [x] 8. **Test with ImagePullBackOff pod**
   - Create test pod with invalid image
   - Run cluster assessment
   - Verify unhealthy pods section shows the pod with correct reason

- [x] 9. **Test with healthy cluster**
   - Run assessment on cluster with no issues
   - Verify "No unhealthy pods detected" message
   - Verify overall health is "HEALTHY"

- [x] 10. **Validate OpenSpec compliance**
    - Run `openspec validate enhance-pod-failure-detection --strict`
    - Fix any validation errors
