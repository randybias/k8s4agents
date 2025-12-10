# Service and Networking Troubleshooting

Comprehensive guide for diagnosing service connectivity, DNS, network policies, and ingress issues.

## Table of Contents

- [Service Basics](#service-basics)
- [DNS Troubleshooting](#dns-troubleshooting)
- [Endpoints and Selectors](#endpoints-and-selectors)
- [Network Policies](#network-policies)
- [Ingress and LoadBalancer](#ingress-and-loadbalancer)
- [Service Mesh Integration](#service-mesh-integration)
- [Connectivity Testing](#connectivity-testing)

## Service Basics

### Service Types

1. **ClusterIP** (default): Internal cluster access only
2. **NodePort**: Exposes service on each node's IP at a static port
3. **LoadBalancer**: Cloud provider load balancer
4. **ExternalName**: CNAME record for external service

### Service Investigation

```bash
# Get service details
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o wide

# Detailed service info
kubectl describe svc <SERVICE_NAME> -n <NAMESPACE>

# Check service YAML
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o yaml

# Check service type
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.spec.type}'
```

### Common Service Issues

1. **No endpoints**
   - Selector doesn't match any pods
   - Pods not ready (failing readiness probes)
   - Pods don't exist

2. **Wrong ports**
   - Service port vs target port mismatch
   - Container listening on different port
   - Protocol mismatch (TCP vs UDP)

3. **Service not accessible**
   - Network policies blocking traffic
   - Firewall rules (for NodePort/LoadBalancer)
   - DNS issues

## DNS Troubleshooting

### DNS Resolution Patterns

**Service DNS Names**:
- Same namespace: `<service-name>`
- Cross-namespace: `<service-name>.<namespace>`
- Fully qualified: `<service-name>.<namespace>.svc.cluster.local`

**Pod DNS Names** (if enabled):
- `<pod-ip-with-dashes>.<namespace>.pod.cluster.local`

### CoreDNS Health Check

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get pods -n kube-system -l k8s-app=coredns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100
kubectl logs -n kube-system -l k8s-app=coredns --tail=100

# Check CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Check CoreDNS service
kubectl get svc kube-dns -n kube-system
kubectl describe svc kube-dns -n kube-system
```

### DNS Resolution Testing

```bash
# Test DNS from within cluster (using debug pod)
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local

# Test with dig for more details
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  dig <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local

# Test from existing pod
kubectl exec -it <POD_NAME> -n <NAMESPACE> -- nslookup <SERVICE_NAME>

# Check pod's DNS configuration
kubectl exec <POD_NAME> -n <NAMESPACE> -- cat /etc/resolv.conf
```

### DNS Policy

```bash
# Check pod DNS policy
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.dnsPolicy}'

# Check custom DNS config
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.dnsConfig}'
```

**DNS Policies**:
- `ClusterFirst` (default): Use cluster DNS, fallback to node DNS
- `Default`: Inherit DNS from node
- `ClusterFirstWithHostNet`: For pods using hostNetwork
- `None`: Custom DNS configuration only

### Common DNS Issues

1. **CoreDNS pods not running**
   ```bash
   # Scale up CoreDNS if needed
   kubectl scale deployment coredns -n kube-system --replicas=2
   ```

2. **CoreDNS configuration errors**
   ```bash
   # Check for configuration syntax errors in logs
   kubectl logs -n kube-system -l k8s-app=kube-dns | grep -i error
   ```

3. **DNS timeout or SERVFAIL**
   - Upstream DNS issues
   - CoreDNS resource constraints
   - Network policies blocking DNS traffic

4. **NXDOMAIN (domain not found)**
   - Typo in service name
   - Service doesn't exist
   - Wrong namespace

## Endpoints and Selectors

### Endpoint Basics

**Endpoints are automatically created by Services and contain IP addresses of pods matching the selector.**

### Endpoint Investigation

```bash
# Check endpoints
kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE>

# Detailed endpoint info
kubectl describe endpoints <SERVICE_NAME> -n <NAMESPACE>

# Get endpoint IPs
kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.subsets[*].addresses[*].ip}'
```

### Selector Matching

```bash
# Get service selector
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.spec.selector}'

# Find pods matching selector
kubectl get pods -n <NAMESPACE> -l <SELECTOR> --show-labels

# Check pod readiness
kubectl get pods -n <NAMESPACE> -l <SELECTOR> -o wide
```

### No Endpoints Issues

**Diagnosis**:
```bash
# 1. Check if selector matches any pods
SERVICE_SELECTOR=$(kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.spec.selector}')
kubectl get pods -n <NAMESPACE> -l $SERVICE_SELECTOR

# 2. Check if matching pods are ready
kubectl get pods -n <NAMESPACE> -l $SERVICE_SELECTOR \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# 3. Check pod labels vs service selector
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o yaml | grep -A 5 selector
kubectl get pods <POD_NAME> -n <NAMESPACE> -o yaml | grep -A 10 labels
```

### Endpoint Slices (Kubernetes 1.21+)

```bash
# Check endpoint slices
kubectl get endpointslices -n <NAMESPACE>

# Detailed endpoint slice info
kubectl describe endpointslice <ENDPOINTSLICE_NAME> -n <NAMESPACE>
```

## Network Policies

### Network Policy Basics

**Network policies control traffic flow between pods and external endpoints.**

**Default Behavior**:
- Without network policies: All traffic allowed
- With network policies: Only explicitly allowed traffic permitted

### Network Policy Investigation

```bash
# List network policies in namespace
kubectl get networkpolicies -n <NAMESPACE>

# Describe specific policy
kubectl describe networkpolicy <POLICY_NAME> -n <NAMESPACE>

# Get policy YAML
kubectl get networkpolicy <POLICY_NAME> -n <NAMESPACE> -o yaml

# List all network policies cluster-wide
kubectl get networkpolicies --all-namespaces
```

### Policy Matching

```bash
# Check if pod is selected by policy
# 1. Get pod labels
kubectl get pod <POD_NAME> -n <NAMESPACE> --show-labels

# 2. Compare with policy pod selector
kubectl get networkpolicy <POLICY_NAME> -n <NAMESPACE> -o jsonpath='{.spec.podSelector}'

# 3. Check policy ingress/egress rules
kubectl get networkpolicy <POLICY_NAME> -n <NAMESPACE> -o yaml | grep -A 20 "ingress"
kubectl get networkpolicy <POLICY_NAME> -n <NAMESPACE> -o yaml | grep -A 20 "egress"
```

### Testing Network Policy

```bash
# Test connectivity before policy
kubectl run source-pod --image=nicolaka/netshoot --restart=Never -- sleep infinity
kubectl run target-pod --image=nginx --restart=Never
kubectl exec source-pod -- curl <TARGET_POD_IP>

# Apply network policy (test config)
# Then test again
kubectl exec source-pod -- curl <TARGET_POD_IP> --max-time 5
```

### Common Network Policy Issues

1. **Deny-all policy blocking everything**
   ```yaml
   # Check for deny-all ingress policy
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: deny-all-ingress
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
   ```

2. **Missing egress rules for DNS**
   - Pods can't resolve DNS if egress blocked
   - Always allow DNS (port 53 UDP/TCP) in egress rules

3. **Namespace selector issues**
   - Policies can't reference pods in other namespaces without namespace selector
   - Check namespace labels

4. **CNI doesn't support network policies**
   - Verify CNI supports network policies (Calico, Cilium, Weave do; Flannel doesn't by default)

### Network Policy Debug

```bash
# Check CNI supports network policies
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | \
  xargs -I {} ssh {} "ls /etc/cni/net.d/"

# Check for network policy controller
kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'

# Check network policy logs (Calico example)
kubectl logs -n kube-system -l k8s-app=calico-node | grep -i "policy"
```

## Ingress and LoadBalancer

### Ingress Investigation

```bash
# List ingress resources
kubectl get ingress -n <NAMESPACE>

# Detailed ingress info
kubectl describe ingress <INGRESS_NAME> -n <NAMESPACE>

# Check ingress class
kubectl get ingressclass

# Check ingress controller pods
kubectl get pods -n ingress-nginx  # For nginx ingress
kubectl get pods -n <INGRESS_CONTROLLER_NAMESPACE>
```

### Ingress Controller Logs

```bash
# Nginx ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100

# Check for specific backend errors
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep <SERVICE_NAME>
```

### LoadBalancer Services

```bash
# Check LoadBalancer status
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o wide

# Check external IP provisioning
kubectl describe svc <SERVICE_NAME> -n <NAMESPACE> | grep -A 5 "LoadBalancer Ingress"

# Check cloud provider events
kubectl get events -n <NAMESPACE> --field-selector involvedObject.name=<SERVICE_NAME>
```

### Common Ingress Issues

1. **Ingress address pending**
   - Ingress controller not running
   - Cloud provider integration issues
   - Resource limits

2. **404 errors**
   - Incorrect path in ingress rules
   - Backend service not found
   - Service selector not matching pods

3. **502/503 errors**
   - Backend pods not ready
   - Service endpoints empty
   - Backend pods unhealthy

4. **TLS/certificate issues**
   ```bash
   # Check TLS secret
   kubectl get secret <TLS_SECRET_NAME> -n <NAMESPACE>
   kubectl get secret <TLS_SECRET_NAME> -n <NAMESPACE> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
   ```

### LoadBalancer Provisioning Issues

**Cloud Provider Specific**:

**AWS (EKS)**:
```bash
# Check AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check service annotations
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.metadata.annotations}'

# Check cloud provider logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Azure (AKS)**:
```bash
# Check cloud-controller-manager
kubectl get pods -n kube-system | grep cloud-controller-manager

# Check service annotations for Azure
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o yaml | grep -A 5 annotations
```

**GCP (GKE)**:
```bash
# Check GKE ingress/load balancer status
kubectl describe svc <SERVICE_NAME> -n <NAMESPACE> | grep -A 10 Events

# Check for GCP-specific annotations
kubectl get svc <SERVICE_NAME> -n <NAMESPACE> -o jsonpath='{.metadata.annotations}'
```

## Service Mesh Integration

### Service Mesh Detection

```bash
# Istio
kubectl get pods -n istio-system
kubectl get mutatingwebhookconfigurations | grep istio

# Linkerd
kubectl get pods -n linkerd
kubectl get mutatingwebhookconfigurations | grep linkerd

# Consul
kubectl get pods -n consul
```

### Sidecar Injection Issues

```bash
# Check if namespace has sidecar injection enabled
kubectl get namespace <NAMESPACE> -o jsonpath='{.metadata.labels}'

# Check pod for sidecar
kubectl get pod <POD_NAME> -n <NAMESPACE> -o jsonpath='{.spec.containers[*].name}'

# Check injection webhook
kubectl get mutatingwebhookconfigurations
```

### Service Mesh Troubleshooting

**Istio**:
```bash
# Check Istio proxy status
kubectl exec <POD_NAME> -n <NAMESPACE> -c istio-proxy -- pilot-agent request GET stats

# Check virtual services
kubectl get virtualservices -n <NAMESPACE>
kubectl describe virtualservice <VS_NAME> -n <NAMESPACE>

# Check destination rules
kubectl get destinationrules -n <NAMESPACE>
```

**Linkerd**:
```bash
# Check Linkerd proxy status
kubectl -n <NAMESPACE> exec <POD_NAME> -c linkerd-proxy -- /bin/sh -c 'curl localhost:4191/ready'

# Check service profiles
kubectl get serviceprofiles -n <NAMESPACE>
```

## Connectivity Testing

### Pod-to-Pod Connectivity

```bash
# Test direct pod IP connectivity
kubectl run source-pod --image=nicolaka/netshoot --restart=Never -- sleep infinity
TARGET_POD_IP=$(kubectl get pod <TARGET_POD> -n <NAMESPACE> -o jsonpath='{.status.podIP}')
kubectl exec source-pod -- ping -c 3 $TARGET_POD_IP
kubectl exec source-pod -- curl http://$TARGET_POD_IP:<PORT>
```

### Pod-to-Service Connectivity

```bash
# Test service DNS and connectivity
kubectl exec source-pod -- nslookup <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local
kubectl exec source-pod -- curl http://<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local:<PORT>

# Test with verbose curl
kubectl exec source-pod -- curl -v http://<SERVICE_NAME>.<NAMESPACE>:<PORT>
```

### External Connectivity

```bash
# Test egress connectivity
kubectl exec <POD_NAME> -n <NAMESPACE> -- curl -I https://www.google.com

# Test with specific DNS server
kubectl exec <POD_NAME> -n <NAMESPACE> -- nslookup www.google.com 8.8.8.8

# Check egress network policies
kubectl get networkpolicies -n <NAMESPACE> -o yaml | grep -A 10 egress
```

### Port Forwarding for Testing

```bash
# Forward pod port to local machine
kubectl port-forward <POD_NAME> -n <NAMESPACE> <LOCAL_PORT>:<POD_PORT>

# Forward service port
kubectl port-forward svc/<SERVICE_NAME> -n <NAMESPACE> <LOCAL_PORT>:<SERVICE_PORT>

# Test from local machine
curl http://localhost:<LOCAL_PORT>
```

### Network Debugging Tools

**nicolaka/netshoot Image** (recommended):
```bash
kubectl run netshoot --image=nicolaka/netshoot --restart=Never -- sleep infinity

# Available tools in netshoot:
# - curl, wget, httpie
# - ping, traceroute, mtr
# - nslookup, dig, host
# - netstat, ss, lsof
# - tcpdump, nmap
# - iperf3, ab (benchmarking)
```

**Debug Container (Kubernetes 1.23+)**:
```bash
# Attach debug container to existing pod
kubectl debug <POD_NAME> -n <NAMESPACE> -it --image=nicolaka/netshoot
```

### Packet Capture

```bash
# Capture traffic on pod
kubectl exec <POD_NAME> -n <NAMESPACE> -- tcpdump -i any -w /tmp/capture.pcap

# Copy capture file for analysis
kubectl cp <NAMESPACE>/<POD_NAME>:/tmp/capture.pcap ./capture.pcap

# Analyze with Wireshark or tcpdump
tcpdump -r capture.pcap
```

## Best Practices

1. **Use FQDN for cross-namespace services** - Avoids ambiguity
2. **Monitor CoreDNS health** - DNS is critical for service discovery
3. **Test with network debugging pods** - Don't rely on application containers
4. **Document network policies** - Complex policies are hard to debug
5. **Use labels consistently** - Simplifies service selection and policy matching
6. **Monitor endpoint health** - Empty endpoints = no traffic
7. **Test from multiple sources** - Network issues can be source-specific
8. **Check CNI compatibility** - Ensure CNI supports required features
9. **Use ingress annotations correctly** - Provider-specific configuration
10. **Validate TLS certificates** - Certificate issues cause mysterious failures

## Common Patterns

### Multi-Tier Application Debugging

```bash
# 1. Test frontend to backend service
kubectl exec <FRONTEND_POD> -n <NAMESPACE> -- curl http://<BACKEND_SERVICE>:<PORT>/health

# 2. Test backend to database service
kubectl exec <BACKEND_POD> -n <NAMESPACE> -- nc -zv <DATABASE_SERVICE> <PORT>

# 3. Check network policies allow required traffic
kubectl get networkpolicies -n <NAMESPACE>

# 4. Verify all service endpoints are ready
kubectl get endpoints -n <NAMESPACE>
```

### Debugging Intermittent Failures

```bash
# 1. Check if endpoints change over time
watch -n 5 'kubectl get endpoints <SERVICE_NAME> -n <NAMESPACE>'

# 2. Test connectivity repeatedly
for i in {1..100}; do
  kubectl exec <POD_NAME> -n <NAMESPACE> -- curl -s http://<SERVICE>:<PORT> || echo "Failed: $i"
done

# 3. Check pod readiness changes
kubectl get pods -n <NAMESPACE> -l <SELECTOR> -w

# 4. Monitor service events
kubectl get events -n <NAMESPACE> --watch
```
