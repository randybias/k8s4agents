# Incident Response Playbooks

Real-world scenario playbooks for common Kubernetes failures with step-by-step diagnosis and resolution procedures.

## Table of Contents

- [CrashLoopBackOff](#crashloopbackoff)
- [OOMKilled](#oomkilled)
- [DNS Resolution Failures](#dns-resolution-failures)
- [ImagePullBackOff](#imagepullbackoff)
- [Node NotReady](#node-notready)
- [Pending Pods](#pending-pods)
- [Stuck Terminating](#stuck-terminating)
- [Service Unreachable](#service-unreachable)
- [PVC Pending](#pvc-pending)
- [Node Disk Pressure](#node-disk-pressure)

## CrashLoopBackOff

### Symptoms
- Pod status shows `CrashLoopBackOff`
- Restart count increasing
- Application unavailable

### Diagnosis Steps

```bash
# 1. Check pod status and restart count
kubectl get pod <POD_NAME> -n <NAMESPACE> -o wide

# 2. Check recent events
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 20 Events

# 3. Get logs from current container
kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER_NAME>

# 4. Get logs from previous crash (critical!)
kubectl logs <POD_NAME> -n <NAMESPACE> -c <CONTAINER_NAME> --previous

# 5. Check exit code and termination reason
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].lastState.terminated}'

# 6. Check liveness/readiness probes
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 10 "livenessProbe\|readinessProbe"
```

### Common Causes & Solutions

**1. Application configuration error**
```bash
# Check environment variables
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].env}'

# Check ConfigMaps and Secrets
kubectl get configmap -n <NAMESPACE>
kubectl get secret -n <NAMESPACE>

# Verify mounted volumes
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 5 "Volumes\|Mounts"
```

**Solution**: Fix configuration, update ConfigMap/Secret, restart pod

**2. Missing dependencies**
```bash
# Check if dependent services are ready
kubectl get svc -n <NAMESPACE>
kubectl get endpoints -n <NAMESPACE>

# Test connectivity to dependencies
kubectl exec <POD_NAME> -n <NAMESPACE> -- nc -zv <DEPENDENCY_SERVICE> <PORT>
```

**Solution**: Ensure dependencies are running, fix network connectivity

**3. Liveness probe failing too quickly**
```bash
# Check probe configuration
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 10 livenessProbe

# Common issues:
# - initialDelaySeconds too short
# - periodSeconds too aggressive
# - timeoutSeconds too short
```

**Solution**: Increase initialDelaySeconds or adjust probe parameters

**4. Resource constraints causing crashes**
```bash
# Check resource limits
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources}'

# Check actual usage
kubectl top pod <POD_NAME> -n <NAMESPACE>
```

**Solution**: Increase resource limits if application needs more

## OOMKilled

### Symptoms
- Pod restarts with exit code 137
- Container terminated reason: `OOMKilled`
- Application dies under load

### Diagnosis Steps

```bash
# 1. Confirm OOMKilled
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'

# 2. Check memory limits
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources.limits.memory}'

# 3. Check memory requests
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources.requests.memory}'

# 4. Check memory usage before crash (if metrics available)
kubectl top pod <POD_NAME> -n <NAMESPACE>

# 5. Check for memory leaks in logs
kubectl logs <POD_NAME> -n <NAMESPACE> --previous | grep -i "memory\|heap\|oom"

# 6. Check node memory pressure
NODE_NAME=$(kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.nodeName}')
kubectl describe node $NODE_NAME | grep -A 5 "Memory Pressure"
```

### Common Causes & Solutions

**1. Memory limit too low**
```bash
# Check typical memory usage pattern
kubectl top pod <POD_NAME> -n <NAMESPACE> --containers

# Check QoS class
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.qosClass}'
```

**Solution**: Increase memory limits appropriately
```yaml
resources:
  limits:
    memory: "2Gi"  # Increased from 1Gi
  requests:
    memory: "1Gi"
```

**2. Memory leak in application**
```bash
# Enable memory profiling (application-specific)
# For Java apps, add JVM flags for heap dump on OOM
# For Node.js, use --max-old-space-size and heap snapshots
# For Go, use pprof
```

**Solution**: Fix memory leak in application code, update deployment

**3. Burst traffic causing memory spike**
```bash
# Check traffic patterns
kubectl logs <POD_NAME> -n <NAMESPACE> --previous | wc -l

# Check if horizontal pod autoscaler exists
kubectl get hpa -n <NAMESPACE>
```

**Solution**: Implement HPA, increase replicas, optimize application

## DNS Resolution Failures

### Symptoms
- Applications can't resolve service names
- `nslookup` or `dig` fails inside pods
- Connection errors to internal services

### Diagnosis Steps

```bash
# 1. Test DNS from within cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local

# 2. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get pods -n kube-system -l k8s-app=coredns

# 3. Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100

# 4. Check pod DNS configuration
kubectl exec <POD_NAME> -n <NAMESPACE> -- cat /etc/resolv.conf

# 5. Test specific service resolution
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local

# 6. Check CoreDNS service
kubectl get svc kube-dns -n kube-system
kubectl describe svc kube-dns -n kube-system
```

### Common Causes & Solutions

**1. CoreDNS pods not running**
```bash
# Check CoreDNS deployment
kubectl get deployment coredns -n kube-system

# Scale up if needed
kubectl scale deployment coredns -n kube-system --replicas=2
```

**Solution**: Ensure CoreDNS pods are running and healthy

**2. CoreDNS configuration error**
```bash
# Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Common issues in Corefile:
# - Wrong cluster domain
# - Missing forward plugin
# - Incorrect upstream DNS
```

**Solution**: Fix CoreDNS ConfigMap, restart CoreDNS pods

**3. Network policy blocking DNS**
```bash
# Check network policies
kubectl get networkpolicies -n <NAMESPACE>

# DNS uses port 53 UDP/TCP
# Ensure egress to kube-system allowed
```

**Solution**: Add network policy rule allowing DNS
```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53
```

**4. Upstream DNS issues**
```bash
# Check if CoreDNS can reach upstream
kubectl exec -n kube-system -it <COREDNS_POD> -- nslookup google.com

# Check forward configuration in Corefile
kubectl get configmap coredns -n kube-system -o yaml | grep -A 5 forward
```

**Solution**: Fix upstream DNS configuration or network connectivity

## ImagePullBackOff

### Symptoms
- Pod stuck in `ImagePullBackOff` or `ErrImagePull`
- Container not starting
- Image pull errors in events

### Diagnosis Steps

```bash
# 1. Check pod events
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 10 Events

# 2. Check image name
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].image}'

# 3. Check imagePullSecrets
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.imagePullSecrets}'

# 4. Verify secret exists
kubectl get secret <SECRET_NAME> -n <NAMESPACE>

# 5. Test image pull from node
NODE_NAME=$(kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.nodeName}')
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host crictl pull <IMAGE_NAME>

# 6. Check image pull policy
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].imagePullPolicy}'
```

### Common Causes & Solutions

**1. Image doesn't exist**
```bash
# Verify image name and tag
# Common mistakes:
# - Typo in image name
# - Wrong tag (e.g., :latest doesn't exist)
# - Wrong registry URL
```

**Solution**: Correct image name and tag in deployment

**2. Registry authentication required**
```bash
# Create docker registry secret
kubectl create secret docker-registry <SECRET_NAME> \
  --docker-server=<REGISTRY_URL> \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD> \
  --docker-email=<EMAIL> \
  -n <NAMESPACE>

# Add to pod spec or service account
kubectl patch serviceaccount default -n <NAMESPACE> -p \
  '{"imagePullSecrets": [{"name": "<SECRET_NAME>"}]}'
```

**Solution**: Configure image pull secrets

**3. Rate limiting (Docker Hub)**
```bash
# Check rate limit in events
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -i "rate limit"

# Use authenticated pulls
# Or use alternative registry (e.g., mirror)
```

**Solution**: Authenticate to Docker Hub or use registry mirror

**4. Network connectivity to registry**
```bash
# Test registry connectivity from node
kubectl debug node/$NODE_NAME -it --image=nicolaka/netshoot -- \
  curl -I https://<REGISTRY_URL>

# Check DNS resolution
kubectl debug node/$NODE_NAME -it --image=nicolaka/netshoot -- \
  nslookup <REGISTRY_URL>
```

**Solution**: Fix network connectivity or firewall rules

## Node NotReady

### Symptoms
- Node status shows `NotReady`
- Pods not scheduling to node
- Cluster capacity reduced

### Diagnosis Steps

```bash
# 1. Check node status
kubectl get nodes -o wide

# 2. Check node conditions
kubectl describe node <NODE_NAME> | grep -A 10 Conditions

# 3. Check kubelet status (requires node access)
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host systemctl status kubelet

# 4. Check kubelet logs
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host journalctl -u kubelet -n 100

# 5. Check node resources
kubectl describe node <NODE_NAME> | grep -A 5 "Allocated resources"

# 6. Check for pressure conditions
kubectl describe node <NODE_NAME> | grep -i "pressure"

# 7. Check CNI health
kubectl get pods -n kube-system -o wide | grep <NODE_NAME>
```

### Common Causes & Solutions

**1. Kubelet not running**
```bash
# Check kubelet status
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host systemctl status kubelet

# Check kubelet config
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host cat /var/lib/kubelet/config.yaml
```

**Solution**: Restart kubelet, fix configuration issues
```bash
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host systemctl restart kubelet
```

**2. Network/CNI issues**
```bash
# Check CNI pod on node
kubectl get pods -n kube-system -l k8s-app=calico-node \
  --field-selector spec.nodeName=<NODE_NAME>

# Check CNI logs
kubectl logs -n kube-system <CNI_POD> --tail=100

# Check CNI configuration
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host ls -la /etc/cni/net.d/
```

**Solution**: Fix CNI issues, restart CNI pod if needed

**3. Disk pressure**
```bash
# Check disk usage on node
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host df -h

# Check for filled disk
kubectl describe node <NODE_NAME> | grep DiskPressure

# Clean up unused containers/images
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host crictl rmi --prune
```

**Solution**: Clean up disk space, increase disk size

**4. Certificate expiration**
```bash
# Check kubelet certificate
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem \
  -noout -dates
```

**Solution**: Renew certificates, restart kubelet

## Pending Pods

### Symptoms
- Pod stuck in `Pending` state
- Pod not scheduled to any node
- Application not starting

### Diagnosis Steps

```bash
# 1. Check pod status
kubectl get pod <POD_NAME> -n <NAMESPACE> -o wide

# 2. Check scheduling events
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 20 Events

# 3. Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# 4. Check pod resource requests
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources.requests}'

# 5. Check node selectors and affinity
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.nodeSelector}'
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.affinity}'

# 6. Check taints and tolerations
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.tolerations}'
```

### Common Causes & Solutions

**1. Insufficient resources**
```bash
# Check available resources per node
kubectl describe nodes | grep -B 5 -A 5 "Allocatable"

# Check resource requests vs available
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].resources.requests}'
```

**Solution**: Reduce resource requests, add nodes, or scale down other pods

**2. Node selector not matching**
```bash
# Check pod node selector
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.nodeSelector}'

# Check node labels
kubectl get nodes --show-labels
```

**Solution**: Fix node selector or add required labels to nodes

**3. Taint not tolerated**
```bash
# Check node taints
kubectl describe node <NODE_NAME> | grep Taints

# Check pod tolerations
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 10 tolerations
```

**Solution**: Add toleration to pod spec or remove node taint

**4. PVC not bound**
```bash
# Check PVC status
kubectl get pvc -n <NAMESPACE>

# Check PVC used by pod
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}'

# Describe PVC
kubectl describe pvc <PVC_NAME> -n <NAMESPACE>
```

**Solution**: Fix PVC binding issue (see PVC Pending playbook)

## Stuck Terminating

### Symptoms
- Pod stuck in `Terminating` state
- Pod not deleted after `kubectl delete`
- Resources not released

### Diagnosis Steps

```bash
# 1. Check pod status
kubectl get pod <POD_NAME> -n <NAMESPACE> -o wide

# 2. Check finalizers
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.metadata.finalizers}'

# 3. Check pod events
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 20 Events

# 4. Check if node is available
kubectl get nodes

# 5. Check for volume unmount issues
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -i volume

# 6. Check deletion timestamp
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.metadata.deletionTimestamp}'
```

### Common Causes & Solutions

**1. Finalizers blocking deletion**
```bash
# Check finalizers
kubectl get pod <POD_NAME> -n <NAMESPACE> -o json | jq .metadata.finalizers

# Remove finalizers (use with caution!)
kubectl patch pod <POD_NAME> -n <NAMESPACE> -p '{"metadata":{"finalizers":null}}'
```

**Solution**: Remove blocking finalizers or fix controller

**2. Volume can't detach**
```bash
# Check volume attachments
kubectl get volumeattachments

# Check for failed detachment
kubectl describe volumeattachment <ATTACHMENT_NAME>

# Force delete attachment (if safe)
kubectl delete volumeattachment <ATTACHMENT_NAME> --force
```

**Solution**: Manually detach volume or force delete pod

**3. Node not responding**
```bash
# Check node status
kubectl get node <NODE_NAME>

# If node is NotReady, pod won't terminate gracefully
```

**Solution**: Force delete pod
```bash
kubectl delete pod <POD_NAME> -n <NAMESPACE> --grace-period=0 --force
```

**4. PreStop hook hanging**
```bash
# Check pod spec for preStop hook
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 10 preStop

# Check pod logs
kubectl logs <POD_NAME> -n <NAMESPACE>
```

**Solution**: Fix or remove preStop hook, force delete if necessary

## Service Unreachable

### Symptoms
- Can't connect to service
- Curl/ping to service fails
- DNS resolves but connection times out

### Diagnosis Steps

```bash
# 1. Check service exists
kubectl get svc <SERVICE_NAME> -n <NAMESPACE>

# 2. Check endpoints
kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE>

# 3. Check if pods are ready
kubectl get pods -n <NAMESPACE> -l <SELECTOR> -o wide

# 4. Test DNS resolution
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local

# 5. Test service connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl <SERVICE_NAME>.<NAMESPACE>:<PORT>

# 6. Check network policies
kubectl get networkpolicies -n <NAMESPACE>

# 7. Test direct pod connectivity
POD_IP=$(kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.status.podIP}')
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl $POD_IP:<PORT>
```

### Common Causes & Solutions

**1. No endpoints (selector mismatch)**
```bash
# Check service selector
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.spec.selector}'

# Check pod labels
kubectl get pods -n <NAMESPACE> --show-labels
```

**Solution**: Fix service selector to match pod labels

**2. Pods not ready**
```bash
# Check readiness probe status
kubectl describe pod <POD_NAME> -n <NAMESPACE> | grep -A 5 "Readiness"

# Check readiness probe configuration
kubectl get pod <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 10 readinessProbe
```

**Solution**: Fix application health check or readiness probe

**3. Network policy blocking traffic**
```bash
# Check policies affecting pods
kubectl describe networkpolicy -n <NAMESPACE>

# Test without policies (temporary, for debugging)
kubectl delete networkpolicy --all -n <NAMESPACE>
```

**Solution**: Add network policy rule allowing required traffic

**4. Wrong port configuration**
```bash
# Check service ports
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.spec.ports}'

# Check container ports
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].ports}'
```

**Solution**: Ensure service targetPort matches container port

## PVC Pending

See `storage-csi.md` for comprehensive PVC troubleshooting. Quick playbook:

### Diagnosis & Solution

```bash
# 1. Check PVC status
kubectl describe pvc <PVC_NAME> -n <NAMESPACE>

# 2. Check StorageClass
kubectl get storageclass

# 3. Check CSI driver
kubectl get pods -n kube-system | grep csi

# 4. Check events
kubectl get events -n <NAMESPACE> --field-selector involvedObject.name=<PVC_NAME>
```

Common fixes:
- Ensure StorageClass exists
- Check CSI driver is running
- Verify sufficient storage quota
- Use WaitForFirstConsumer binding mode

## Node Disk Pressure

### Symptoms
- Node has `DiskPressure` condition
- Pods evicted from node
- New pods can't schedule to node

### Diagnosis & Solution

```bash
# 1. Check disk usage
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host df -h

# 2. Check for large files
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host du -sh /* | sort -hr | head -20

# 3. Clean up unused images
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host crictl rmi --prune

# 4. Clean up stopped containers
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host crictl rm $(chroot /host crictl ps -a -q --state=exited)

# 5. Clean up logs
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- \
  chroot /host find /var/log -type f -name "*.log" -size +100M
```

**Solution**: Clean up disk space, increase disk size, configure log rotation

## Best Practices for Incident Response

1. **Always check events first** - Most issues show up in events
2. **Collect logs before actions** - Preserve evidence
3. **Work methodically** - Follow playbook steps
4. **Document findings** - For post-mortem
5. **Test in staging first** - When possible
6. **Have rollback plan** - Before making changes
7. **Monitor during resolution** - Watch for side effects
8. **Update runbooks** - Capture new learnings
9. **Communicate status** - Keep stakeholders informed
10. **Conduct post-mortem** - Learn and improve
