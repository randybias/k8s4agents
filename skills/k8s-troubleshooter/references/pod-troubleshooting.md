# Pod Troubleshooting Deep Dive

Comprehensive guide for diagnosing pod lifecycle issues, container failures, and runtime problems.

## Table of Contents

- [Pod Lifecycle States](#pod-lifecycle-states)
- [Container States and Exit Codes](#container-states-and-exit-codes)
- [Events and Logs Correlation](#events-and-logs-correlation)
- [Init Containers](#init-containers)
- [Probes and Health Checks](#probes-and-health-checks)
- [Image Pull Issues](#image-pull-issues)
- [Resource Management](#resource-management)
- [Security Context Problems](#security-context-problems)
- [Pod Disruption and Eviction](#pod-disruption-and-eviction)

## Pod Lifecycle States

### Pending

**Meaning**: Pod accepted by cluster but not yet running

**Common Causes**:
1. **Scheduling Failures**
   ```bash
   # Check scheduling events
   kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 10 "Events"

   # Check node resources
   kubectl describe nodes | grep -A 5 "Allocated resources"

   # Check taints and tolerations
   kubectl get nodes -o json | jq '.items[].spec.taints'
   ```

2. **Insufficient Resources**
   ```bash
   # Check pod resource requests
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources}'

   # Check namespace resource quotas
   kubectl get resourcequota -n <NAMESPACE>
   kubectl describe resourcequota <QUOTA_NAME> -n <NAMESPACE>
   ```

3. **PVC Binding Issues**
   ```bash
   # Check PVC status
   kubectl get pvc -n <NAMESPACE>
   kubectl describe pvc <PVC_NAME> -n <NAMESPACE>
   ```

4. **Node Selector/Affinity Mismatch**
   ```bash
   # Check pod node selector
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.nodeSelector}'

   # Check node labels
   kubectl get nodes --show-labels

   # Check affinity rules
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.affinity}'
   ```

### Running

**Meaning**: Pod bound to node and all containers created

**Potential Issues Even When Running**:
- Readiness probe failures (pod not receiving traffic)
- Liveness probe failures (pod will be restarted)
- Application errors (check logs)

### Succeeded / Failed

**Meaning**: All containers terminated (Succeeded = exit 0, Failed = non-zero exit)

**Investigation**:
```bash
# Check final status
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.phase}'

# Get container exit codes
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].state.terminated}'
```

### Unknown

**Meaning**: Communication lost with node hosting the pod

**Actions**:
```bash
# Check node status
kubectl get nodes
kubectl describe node <NODE_NAME>

# Check if node is responding
kubectl get events --all-namespaces --field-selector involvedObject.name=<NODE_NAME>
```

## Container States and Exit Codes

### Common Exit Codes

| Exit Code | Meaning | Common Causes |
|-----------|---------|---------------|
| 0 | Success | Normal termination |
| 1 | Generic error | Application error, missing dependency |
| 2 | Misuse of shell | Command not found, syntax error |
| 126 | Command cannot execute | Permission issue, not executable |
| 127 | Command not found | Path issue, typo in command |
| 128+n | Fatal error signal n | 137 (SIGKILL), 139 (SIGSEGV), 143 (SIGTERM) |
| 130 | SIGINT (Ctrl+C) | Interrupted by user/system |
| 137 | SIGKILL | OOMKilled or forced termination |
| 139 | SIGSEGV | Segmentation fault |
| 143 | SIGTERM | Graceful termination signal |
| 255 | Exit status out of range | Application panic or crash |

### Retrieving Exit Codes

```bash
# Current container state
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].state}'

# Last termination info
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].lastState.terminated}'

# All container statuses
kubectl get pod <POD_NAME> -n <NAMESPACE> -o json | jq '.status.containerStatuses'
```

### OOMKilled (Exit 137)

**Diagnosis**:
```bash
# Check if OOMKilled
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'

# Check memory limits
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources.limits.memory}'

# Check actual memory usage (if pod still running)
kubectl top pod <POD_NAME> -n <NAMESPACE>

# Check node memory pressure
kubectl describe node <NODE_NAME> | grep -A 5 "Conditions"
```

**Resolution Strategies**:
1. Increase memory limits
2. Investigate memory leaks in application
3. Add memory profiling
4. Review memory requests vs limits ratio

### CrashLoopBackOff

**Meaning**: Container repeatedly crashing, Kubernetes backing off restart attempts

**Investigation**:
```bash
# Get current logs
kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER_NAME>

# Get logs from previous crash
kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER_NAME> --previous

# Check restart count
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].restartCount}'

# Get detailed crash info
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 20 "Last State"
```

**Common Causes**:
1. Application configuration errors
2. Missing environment variables
3. Failed health checks
4. Dependency unavailability (database, external service)
5. Insufficient permissions (filesystem, network)

## Events and Logs Correlation

### Timeline Analysis

**Collect Event Timeline**:
```bash
# Pod-specific events
kubectl get events -n <NAMESPACE> \
  --field-selector involvedObject.name=<POD_NAME> \
  --sort-by='.lastTimestamp'

# Namespace-wide events (recent)
kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp' | tail -50

# All cluster events (filtered by time)
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep <SEARCH_TERM>
```

**Correlate Logs with Events**:
```bash
# Get logs with timestamps
kubectl logs <POD_NAME> -n <NAMESPACE> --timestamps=true

# Logs from specific time range (requires recent kubectl)
kubectl logs <POD_NAME> -n <NAMESPACE> --since-time=<RFC3339_TIMESTAMP>

# Logs from last N minutes
kubectl logs <POD_NAME> -n <NAMESPACE> --since=30m

# Follow logs in real-time
kubectl logs <POD_NAME> -n <NAMESPACE> -f
```

### Multi-Container Pods

```bash
# List all containers in pod
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].name}'

# Get logs from specific container
kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER_NAME>

# Get logs from all containers
for container in $(kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].name}'); do
  echo "=== Container: $container ==="
  kubectl logs <POD_NAME> -n <NAMESPACE> -c $container --tail=50
done
```

## Init Containers

### Init Container Sequence

**Init containers run sequentially before app containers. If any init container fails, pod won't start.**

**Diagnosis**:
```bash
# Check init container status
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.initContainerStatuses[*].state}'

# Get init container logs
kubectl logs <POD_NAME> -n <NAMESPACE> -c <INIT_CONTAINER_NAME>

# Check which init container failed
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 10 "Init Containers"
```

**Common Init Container Use Cases**:
1. Database schema migrations
2. Configuration file generation
3. Waiting for dependencies (services, volumes)
4. Certificate/secret management
5. Git repository cloning

## Probes and Health Checks

### Probe Types

1. **Liveness Probe**: Determines if container should be restarted
2. **Readiness Probe**: Determines if container should receive traffic
3. **Startup Probe**: Determines if application has started (delays liveness/readiness)

### Probe Configuration

```bash
# View probe configuration
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 20 "livenessProbe"
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 20 "readinessProbe"
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 20 "startupProbe"
```

### Probe Failure Investigation

```bash
# Check probe failures in events
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -i "unhealthy\|failed"

# Test probe endpoint manually (exec into pod)
kubectl exec -it <POD_NAME> -n <NAMESPACE> -- curl localhost:<PORT><PROBE_PATH>

# Test probe endpoint from debug container
kubectl debug <POD_NAME> -n <NAMESPACE> -it --image=nicolaka/netshoot -- \
  curl <POD_IP>:<PORT><PROBE_PATH>
```

### Common Probe Issues

1. **Timeout too short**: Application slow to respond
2. **Initial delay too short**: Application not ready yet
3. **Wrong endpoint**: Path doesn't exist or returns error
4. **Misconfigured probes**: Wrong port, path, or headers
5. **Resource constraints**: CPU/memory throttling affects response time

## Image Pull Issues

### ImagePullBackOff / ErrImagePull

**Common Causes**:

1. **Image doesn't exist**
   ```bash
   # Verify image name
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].image}'

   # Check image pull events
   kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 5 "Failed to pull image"
   ```

2. **Authentication required**
   ```bash
   # Check imagePullSecrets
   kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.imagePullSecrets}'

   # Verify secret exists
   kubectl get secret <SECRET_NAME> -n <NAMESPACE>

   # Check secret content (base64 encoded)
   kubectl get secret <SECRET_NAME> -n <NAMESPACE> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
   ```

3. **Registry unreachable**
   ```bash
   # Test registry connectivity from node
   kubectl debug node/<NODE_NAME> -it --image=nicolaka/netshoot -- \
     curl -I https://<REGISTRY_URL>

   # Check node DNS resolution
   kubectl debug node/<NODE_NAME> -it --image=nicolaka/netshoot -- \
     nslookup <REGISTRY_URL>
   ```

4. **Rate limiting (Docker Hub)**
   - Docker Hub enforces pull rate limits
   - Use authenticated pulls or alternative registries
   - Check current rate limit status in events

### Image Pull Policy

```bash
# Check image pull policy
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].imagePullPolicy}'
```

**Policies**:
- `Always`: Pull image on every pod start (default for `:latest`)
- `IfNotPresent`: Pull only if not cached on node (default for tagged images)
- `Never`: Never pull, use cached image only

## Resource Management

### Resource Requests and Limits

```bash
# View resource configuration
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources}'

# Check actual usage
kubectl top pod <POD_NAME> -n <NAMESPACE>

# Check QoS class
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.qosClass}'
```

### QoS Classes

1. **Guaranteed**: Requests = Limits for all containers
2. **Burstable**: At least one container has request or limit
3. **BestEffort**: No requests or limits set

### CPU Throttling

```bash
# Check for CPU throttling (requires node access)
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host cat /sys/fs/cgroup/cpu,cpuacct/kubepods/pod<POD_UID>/cpu.stat
```

### Resource Quota Exceeded

```bash
# Check namespace quotas
kubectl get resourcequota -n <NAMESPACE>
kubectl describe resourcequota -n <NAMESPACE>

# Check current usage
kubectl describe namespace <NAMESPACE>
```

## Security Context Problems

### Permission Denied Errors

```bash
# Check security context
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.securityContext}'
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].securityContext}'

# Check user/group settings
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.securityContext.runAsUser}'
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.securityContext.fsGroup}'
```

### Pod Security Standards

```bash
# Check namespace pod security admission
kubectl get namespace <NAMESPACE> -o yaml | grep -A 5 "pod-security"

# Check pod security violations in events
kubectl get events -n <NAMESPACE> --field-selector reason=FailedCreate
```

### Capabilities and Privileged Mode

```bash
# Check if container is privileged
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].securityContext.privileged}'

# Check capabilities
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].securityContext.capabilities}'
```

## Pod Disruption and Eviction

### Pod Disruption Budgets

```bash
# Check PDBs
kubectl get pdb -n <NAMESPACE>
kubectl describe pdb <PDB_NAME> -n <NAMESPACE>

# Check if PDB is blocking operations
kubectl get events -n <NAMESPACE> | grep "PodDisruptionBudget"
```

### Node Eviction

**Eviction Reasons**:
1. Node resource pressure (disk, memory, PIDs)
2. Node maintenance (drain)
3. Cluster autoscaler downscaling

```bash
# Check evicted pods
kubectl get pods --all-namespaces --field-selector status.phase=Failed | grep Evicted

# Get eviction reason
kubectl get pod <EVICTED_POD> -n <NAMESPACE> -o jsonpath='{.status.reason}'
kubectl get pod <EVICTED_POD> -n <NAMESPACE> -o jsonpath='{.status.message}'

# Check node conditions
kubectl describe node <NODE_NAME> | grep -A 10 "Conditions"
```

### Preemption

**Lower priority pods may be preempted to make room for higher priority pods**

```bash
# Check pod priority
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.priorityClassName}'

# List priority classes
kubectl get priorityclasses

# Check preemption events
kubectl get events -n <NAMESPACE> | grep Preempt
```

## Debugging Techniques

### Interactive Debugging

```bash
# Ephemeral debug container (Kubernetes 1.23+)
kubectl debug <POD_NAME> -n <NAMESPACE> -it --image=nicolaka/netshoot

# Debug by copying pod
kubectl debug <POD_NAME> -n <NAMESPACE> -it --copy-to=<DEBUG_POD_NAME> --container=<CONTAINER_NAME> -- sh

# Replace container image for debugging
kubectl debug <POD_NAME> -n <NAMESPACE> -it --copy-to=<DEBUG_POD_NAME> \
  --set-image=<CONTAINER_NAME>=busybox -- sh
```

### Network Debugging

```bash
# Check container network namespace
kubectl exec <POD_NAME> -n <NAMESPACE> -- ip addr
kubectl exec <POD_NAME> -n <NAMESPACE> -- ip route

# Check DNS configuration
kubectl exec <POD_NAME> -n <NAMESPACE> -- cat /etc/resolv.conf

# Test connectivity
kubectl exec <POD_NAME> -n <NAMESPACE> -- ping <TARGET_IP>
kubectl exec <POD_NAME> -n <NAMESPACE> -- curl <TARGET_URL>
```

### Filesystem Debugging

```bash
# Check mounted volumes
kubectl exec <POD_NAME> -n <NAMESPACE> -- df -h

# Check file permissions
kubectl exec <POD_NAME> -n <NAMESPACE> -- ls -la <PATH>

# Copy files from pod for analysis
kubectl cp <NAMESPACE>/<POD_NAME>:<POD_PATH> <LOCAL_PATH>
```

## Best Practices

1. **Always check events first** - Most issues show up in events
2. **Correlate logs with timestamps** - Events + logs = complete picture
3. **Check previous container logs** - Crash information often in previous instance
4. **Verify dependencies** - ConfigMaps, Secrets, PVCs, Services
5. **Resource monitoring** - Use `kubectl top` to identify resource issues
6. **Test probes manually** - Ensure health check endpoints work correctly
7. **Review security context** - Permission errors often security-related
8. **Check QoS class** - Affects eviction order during resource pressure
