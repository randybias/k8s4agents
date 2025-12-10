# Calico CNI Troubleshooting

Comprehensive guide for diagnosing Calico and CNI issues in Kubernetes clusters.

## Table of Contents

- [Calico Architecture](#calico-architecture)
- [Calico Health Check](#calico-health-check)
- [Node Connectivity Issues](#node-connectivity-issues)
- [IPAM and IP Pool Management](#ipam-and-ip-pool-management)
- [BGP Configuration](#bgp-configuration)
- [Network Policy Debugging](#network-policy-debugging)
- [Felix and Dataplane](#felix-and-dataplane)
- [Performance and Scaling](#performance-and-scaling)

## Calico Architecture

### Components

1. **calico-node**: Runs on each node (DaemonSet)
   - Felix: Policy enforcement and route programming
   - BIRD: BGP routing daemon
   - confd: Configuration management

2. **calico-kube-controllers**: Cluster-wide controller
   - Watches Kubernetes API
   - Manages Calico resources

3. **calico-typha**: (Optional) Caching layer for large clusters
   - Reduces API server load
   - Recommended for >50 nodes

4. **CNI Plugin**: Container network interface binary
   - IPAM (IP address management)
   - Network setup for pods

### Calico Modes

- **IPIP**: IP-in-IP encapsulation (compatibility mode)
- **VXLAN**: VXLAN encapsulation (no BGP required)
- **Direct**: No encapsulation (requires L2 connectivity)
- **Wireguard**: Encrypted pod traffic

## Calico Health Check

### Initial Investigation

```bash
# Check calico-node pods
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide

# Check calico-node status on all nodes
kubectl get pods -n kube-system -l k8s-app=calico-node -o json | \
  jq -r '.items[] | "\(.spec.nodeName)\t\(.status.phase)"'

# Check calico-kube-controllers
kubectl get pods -n kube-system -l k8s-app=calico-kube-controllers

# Check Typha (if deployed)
kubectl get pods -n kube-system -l k8s-app=calico-typha
```

### Calico Node Status

```bash
# Get calico-node pod on specific node
NODE_NAME=<NODE_NAME>
CALICO_POD=$(kubectl get pod -n kube-system -l k8s-app=calico-node \
  --field-selector spec.nodeName=$NODE_NAME -o jsonpath='{.items[0].metadata.name}')

# Check Felix readiness
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calico-node -felix-ready

# Check BIRD readiness (if using BGP)
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calico-node -bird-ready

# Check node status
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calicoctl node status
```

### Calico Logs

```bash
# Felix logs
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep felix

# BIRD logs (BGP)
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep bird

# CNI logs (requires node access)
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host tail -f /var/log/calico/cni/cni.log
```

## Node Connectivity Issues

### Pod IP Allocation

```bash
# Check IP pools
kubectl get ippools

# Describe IP pool
kubectl describe ippool <POOL_NAME>

# Check IP pool utilization
kubectl get ippool <POOL_NAME> -o jsonpath='{.spec.blockSize}' && echo
kubectl get ippools -o json | jq '.items[] | {name: .metadata.name, cidr: .spec.cidr, blockSize: .spec.blockSize}'

# Check if node has IP blocks assigned
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calicoctl ipam show --show-blocks
```

### Workload Endpoints

```bash
# List all workload endpoints
kubectl get workloadendpoints --all-namespaces

# Get workload endpoint for specific pod
POD_NAME=<POD_NAME>
NAMESPACE=<NAMESPACE>
kubectl get workloadendpoint -n $NAMESPACE | grep $POD_NAME

# Describe workload endpoint
kubectl describe workloadendpoint -n $NAMESPACE <WORKLOADENDPOINT_NAME>
```

### Route Programming

```bash
# Check routes on node
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host ip route

# Check Calico-programmed routes
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host ip route | grep cali

# Check for route conflicts
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host ip route show table all
```

### Interface Status

```bash
# List Calico interfaces on node
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host ip link show | grep cali

# Check interface statistics
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host ip -s link show

# Check for interface errors
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host ifconfig | grep -i error
```

## IPAM and IP Pool Management

### IP Pool Configuration

```bash
# Get IP pools
kubectl get ippools -o yaml

# Check IP pool CIDR
kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.cidr}'

# Check NAT configuration
kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.natOutgoing}'

# Check disabled status
kubectl get ippool default-ipv4-ippool -o jsonpath='{.spec.disabled}'
```

### IP Address Assignment

```bash
# Show IP assignments
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calicoctl ipam show

# Show blocks allocated to nodes
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calicoctl ipam show --show-blocks

# Show IP configuration per node
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calicoctl ipam show --show-configuration
```

### IP Pool Exhaustion

```bash
# Check available IPs
kubectl get ippools -o json | jq '.items[] | {name: .metadata.name, cidr: .spec.cidr, blockSize: .spec.blockSize}'

# Count allocated workload endpoints
kubectl get workloadendpoints --all-namespaces | wc -l

# Calculate IP pool capacity
# Capacity = (2^(32 - CIDR_PREFIX)) - overhead

# Check for IP leaks
kubectl get workloadendpoints --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.node != null) | "\(.spec.node)\t\(.spec.pod)\t\(.spec.ipNetworks[0])"' | \
  sort
```

### IPAM Issues

**Duplicate IP addresses**:
```bash
# Check for duplicate IPs
kubectl get workloadendpoints --all-namespaces -o json | \
  jq -r '.items[] | .spec.ipNetworks[0]' | sort | uniq -d

# Release IP (if stuck)
kubectl exec -n kube-system $CALICO_POD -c calico-node -- \
  calicoctl ipam release --ip=<IP_ADDRESS>
```

**IP assignment failures**:
```bash
# Check CNI logs for IPAM errors
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host cat /var/log/calico/cni/cni.log | grep -i "ipam\|failed"

# Check IP pool affinity
kubectl get ippools -o yaml | grep -A 5 nodeSelector

# Verify IP pool is not disabled
kubectl get ippool -o jsonpath='{.items[*].spec.disabled}'
```

## BGP Configuration

### BGP Status

```bash
# Check BGP status
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calicoctl node status

# Detailed BGP peer status
kubectl exec -n kube-system $CALICO_POD -c calico-node -- birdcl show protocols all

# BGP routes
kubectl exec -n kube-system $CALICO_POD -c calico-node -- birdcl show route

# BGP neighbor summary
kubectl exec -n kube-system $CALICO_POD -c calico-node -- birdcl show protocols | grep BGP
```

### BGP Configuration

```bash
# Get BGP configuration
kubectl get bgpconfig default -o yaml

# Get BGP peer configuration
kubectl get bgppeers

# Describe BGP peer
kubectl describe bgppeer <PEER_NAME>

# Check node BGP configuration
kubectl exec -n kube-system $CALICO_POD -c calico-node -- cat /etc/calico/confd/config/bird.cfg
```

### BGP Peering Issues

**No BGP peers established**:
```bash
# Check node-to-node mesh is enabled
kubectl get bgpconfig default -o jsonpath='{.spec.nodeToNodeMeshEnabled}'

# Check AS number
kubectl get bgpconfig default -o jsonpath='{.spec.asNumber}'

# Check for firewall blocking BGP (TCP 179)
kubectl exec -n kube-system $CALICO_POD -c calico-node -- nc -zv <PEER_NODE_IP> 179

# Check BIRD logs
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep -i "bird\|bgp"
```

**Route not advertised**:
```bash
# Check if route exists in BIRD
kubectl exec -n kube-system $CALICO_POD -c calico-node -- birdcl show route for <POD_CIDR>

# Check BGP export filters
kubectl exec -n kube-system $CALICO_POD -c calico-node -- cat /etc/calico/confd/config/bird.cfg | grep -A 10 export

# Verify IP pool is advertised
kubectl get ippool -o jsonpath='{.items[*].spec.disabled}'
```

### Route Reflector Configuration

```bash
# Check for route reflector configuration
kubectl get nodes -l calico-route-reflector=true

# Get BGP peer configuration for RR
kubectl get bgppeer -o yaml

# Check RR cluster ID
kubectl get bgpconfig default -o jsonpath='{.spec.routeReflectorClusterID}'
```

## Network Policy Debugging

### Policy Investigation

```bash
# List Calico network policies
kubectl get networkpolicies --all-namespaces
kubectl get globalnetworkpolicies

# Describe specific policy
kubectl describe networkpolicy <POLICY_NAME> -n <NAMESPACE>

# Get Calico-specific policies
kubectl get caliconetworkpolicies --all-namespaces
kubectl describe caliconetworkpolicy <POLICY_NAME> -n <NAMESPACE>
```

### Policy Application

```bash
# Check which policies apply to pod
POD_NAME=<POD_NAME>
NAMESPACE=<NAMESPACE>

# Get pod labels
kubectl get pod $POD_NAME -n $NAMESPACE --show-labels

# Find policies selecting this pod
kubectl get networkpolicies -n $NAMESPACE -o json | \
  jq -r '.items[] | select(.spec.podSelector | length > 0) | .metadata.name'

# Get workload endpoint to see applied policies
kubectl get workloadendpoint -n $NAMESPACE -o json | \
  jq '.items[] | select(.metadata.name | contains("'$POD_NAME'")) | .spec.profiles'
```

### Policy Ordering

```bash
# Check policy tier and order (Calico Enterprise)
kubectl get tier
kubectl get globalnetworkpolicies -o custom-columns=NAME:.metadata.name,ORDER:.spec.order

# Check policy statistics
kubectl exec -n kube-system $CALICO_POD -c calico-node -- \
  calico-node -felix-info | grep -i policy
```

### Policy Troubleshooting

```bash
# Enable Felix debug logging
kubectl exec -n kube-system $CALICO_POD -c calico-node -- \
  calico-node -felix-set-log-level debug

# Check policy application in Felix logs
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep -i "policy\|rule"

# Test connectivity
SOURCE_POD=<SOURCE_POD>
TARGET_POD_IP=<TARGET_IP>
kubectl exec $SOURCE_POD -n $NAMESPACE -- curl -v --connect-timeout 5 http://$TARGET_POD_IP:80

# Reset log level
kubectl exec -n kube-system $CALICO_POD -c calico-node -- \
  calico-node -felix-set-log-level info
```

## Felix and Dataplane

### Felix Configuration

```bash
# Get Felix configuration
kubectl get felixconfiguration default -o yaml

# Check dataplane mode
kubectl get felixconfiguration default -o jsonpath='{.spec.dataplaneDriver}'

# Check logging level
kubectl get felixconfiguration default -o jsonpath='{.spec.logSeverityScreen}'

# Check iptables backend
kubectl get felixconfiguration default -o jsonpath='{.spec.iptablesBackend}'
```

### Iptables Rules

```bash
# Check Calico iptables chains
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host iptables -L -n -v -t filter | grep cali

# Check NAT rules
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host iptables -L -n -v -t nat | grep cali

# Check for dropped packets
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host iptables -L -n -v -t filter | grep cali | grep DROP

# Save iptables rules for analysis
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host iptables-save > iptables-rules.txt
```

### eBPF Dataplane (if enabled)

```bash
# Check if eBPF is enabled
kubectl get felixconfiguration default -o jsonpath='{.spec.bpfEnabled}'

# Check eBPF programs
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host tc filter show dev eth0 ingress

# Check eBPF maps
kubectl exec -n kube-system $CALICO_POD -c calico-node -- \
  calico-node -bpf maps dump

# eBPF program logs
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep -i bpf
```

### Dataplane Issues

**Packets not forwarded**:
```bash
# Check IP forwarding enabled
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host sysctl net.ipv4.ip_forward

# Check RPF (Reverse Path Filtering)
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host sysctl net.ipv4.conf.all.rp_filter

# Check interface forwarding
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host cat /proc/sys/net/ipv4/conf/cali*/forwarding
```

**Packets dropped by iptables**:
```bash
# Enable iptables packet tracing
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host iptables -t raw -A PREROUTING -p tcp --dport 80 -j TRACE

# Check kernel logs for trace
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host dmesg | grep TRACE

# Disable tracing after investigation
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host iptables -t raw -D PREROUTING -p tcp --dport 80 -j TRACE
```

## Performance and Scaling

### Performance Metrics

```bash
# Felix metrics (requires Prometheus)
kubectl exec -n kube-system $CALICO_POD -c calico-node -- \
  curl -s http://localhost:9091/metrics | grep felix

# Check for performance warnings in logs
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep -i "slow\|performance\|timeout"

# Check dataplane statistics
kubectl debug node/$NODE_NAME -it --image=ubuntu -- \
  chroot /host iptables -L -n -v -t filter | head -20
```

### Typha for Large Clusters

```bash
# Check if Typha is deployed
kubectl get deployment -n kube-system calico-typha

# Check Typha connections
kubectl get pods -n kube-system -l k8s-app=calico-typha

# Typha logs
kubectl logs -n kube-system -l k8s-app=calico-typha --tail=100

# Check calico-node connection to Typha
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep -i typha

# Verify Typha service
kubectl get svc -n kube-system calico-typha
```

### Resource Utilization

```bash
# Check calico-node resource usage
kubectl top pod -n kube-system -l k8s-app=calico-node

# Check calico-node limits and requests
kubectl get pods -n kube-system -l k8s-app=calico-node -o jsonpath='{.items[0].spec.containers[0].resources}'

# Check for OOMKilled events
kubectl get events -n kube-system --field-selector reason=OOMKilled,involvedObject.name~=calico
```

### Scaling Considerations

**Large number of nodes (>100)**:
- Deploy Typha (reduce API server load)
- Tune Felix sync intervals
- Use route reflectors for BGP
- Consider eBPF dataplane

**Large number of network policies (>1000)**:
- Use policy tiers and ordering
- Minimize policy complexity
- Use namespace selectors efficiently
- Consider Calico Enterprise for policy performance

**High pod churn**:
- Monitor IPAM performance
- Check for IP address exhaustion
- Tune workload endpoint cleanup
- Monitor etcd/k8s API performance

## Troubleshooting Checklist

When debugging Calico issues:

1. ✓ Check calico-node pods healthy on all nodes
2. ✓ Verify Felix and BIRD ready (if using BGP)
3. ✓ Check IP pools and IPAM
4. ✓ Verify BGP peering (if enabled)
5. ✓ Check workload endpoints created for pods
6. ✓ Verify routes programmed on nodes
7. ✓ Test pod-to-pod connectivity
8. ✓ Check network policies
9. ✓ Review Felix and BIRD logs
10. ✓ Verify dataplane (iptables/eBPF) rules

## Common Patterns

### Diagnosing Pod Connectivity Failure

```bash
# 1. Check pod IPs assigned
kubectl get pod <POD1> -n <NAMESPACE> -o jsonpath='{.status.podIP}'
kubectl get pod <POD2> -n <NAMESPACE> -o jsonpath='{.status.podIP}'

# 2. Check workload endpoints exist
kubectl get workloadendpoints -n <NAMESPACE> | grep <POD_NAME>

# 3. Check routes on source node
SOURCE_NODE=$(kubectl get pod <POD1> -n <NAMESPACE> -o jsonpath='{.spec.nodeName}')
kubectl debug node/$SOURCE_NODE -it --image=ubuntu -- \
  chroot /host ip route get <TARGET_POD_IP>

# 4. Test connectivity
kubectl exec <POD1> -n <NAMESPACE> -- ping -c 3 <TARGET_POD_IP>

# 5. Check network policies
kubectl get networkpolicies -n <NAMESPACE>

# 6. Check Felix logs for drops
kubectl logs -n kube-system -l k8s-app=calico-node --field-selector spec.nodeName=$SOURCE_NODE | grep -i drop
```

### Diagnosing BGP Issues

```bash
# 1. Check BGP mesh enabled
kubectl get bgpconfig default -o jsonpath='{.spec.nodeToNodeMeshEnabled}'

# 2. Check BGP peers on node
kubectl exec -n kube-system $CALICO_POD -c calico-node -- calicoctl node status

# 3. Check BIRD status
kubectl exec -n kube-system $CALICO_POD -c calico-node -- birdcl show protocols

# 4. Check routes advertised
kubectl exec -n kube-system $CALICO_POD -c calico-node -- birdcl show route

# 5. Check firewall (BGP uses TCP 179)
kubectl exec -n kube-system $CALICO_POD -c calico-node -- nc -zv <PEER_IP> 179

# 6. Check BIRD logs
kubectl logs -n kube-system $CALICO_POD -c calico-node | grep -i bird
```

## Best Practices

1. **Monitor Calico components** - Set up alerts for calico-node failures
2. **Use Typha for large clusters** - Reduces API server load
3. **Plan IP pools carefully** - Ensure sufficient IP space
4. **Use WireGuard for encryption** - Better performance than IPsec
5. **Optimize BGP configuration** - Use route reflectors for large clusters
6. **Keep policies organized** - Use tiers and naming conventions
7. **Monitor IPAM usage** - Prevent IP exhaustion
8. **Test policy changes** - Use staging environment first
9. **Regular version updates** - Keep Calico up to date
10. **Enable metrics** - Integrate with Prometheus for visibility
