# MCP Integration Guide

This guide explains how to integrate Model Context Protocol (MCP) servers with the Kubernetes Troubleshooter skill for enhanced cluster introspection capabilities.

## Table of Contents

- [Overview](#overview)
- [MCP Server Setup](#mcp-server-setup)
- [Read-Only Access Patterns](#read-only-access-patterns)
- [Security and Token Hygiene](#security-and-token-hygiene)
- [Common Use Cases](#common-use-cases)
- [Troubleshooting MCP Integration](#troubleshooting-mcp-integration)

## Overview

MCP servers provide a standardized way for Claude to interact with Kubernetes clusters. By integrating an MCP server, you can:

- Execute kubectl commands directly from Claude
- Query cluster state without manual command execution
- Maintain audit logs of all cluster interactions
- Enforce read-only access policies programmatically

## MCP Server Setup

### Prerequisites

- kubectl configured with cluster access
- Python 3.8+ or Node.js 18+ (depending on MCP server implementation)
- Valid kubeconfig file with appropriate permissions

### Recommended MCP Servers

1. **kubernetes-mcp-server** (Python-based)
   - Repository: Various community implementations
   - Features: Read-only kubectl operations, namespace filtering
   - Installation: Follow repository-specific instructions

2. **kubectl-mcp** (Node.js-based)
   - Features: Full kubectl API coverage with permission controls
   - Configuration: Environment-based access control

### Basic Configuration

Example MCP server configuration for Claude Code:

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "python",
      "args": ["-m", "kubernetes_mcp_server"],
      "env": {
        "KUBECONFIG": "/path/to/kubeconfig",
        "READ_ONLY": "true",
        "ALLOWED_NAMESPACES": "default,kube-system"
      }
    }
  }
}
```

## Read-Only Access Patterns

### Enforcing Read-Only Operations

The MCP server should restrict operations to:

- `kubectl get` - Retrieve resource information
- `kubectl describe` - Get detailed resource descriptions
- `kubectl logs` - Read container logs
- `kubectl top` - View resource usage metrics
- `kubectl exec` with read-only commands (optional, requires careful scoping)

### Blocked Operations

The following operations should be blocked in diagnostic contexts:

- `kubectl delete` - Resource deletion
- `kubectl apply` - Resource creation/modification
- `kubectl edit` - Direct resource editing
- `kubectl scale` - Scaling operations
- `kubectl patch` - Resource patching
- `kubectl replace` - Resource replacement

### Implementation Example

Example Python-based access control:

```python
ALLOWED_VERBS = ['get', 'describe', 'logs', 'top']
BLOCKED_VERBS = ['delete', 'apply', 'edit', 'scale', 'patch', 'replace']

def validate_command(kubectl_args):
    verb = kubectl_args[0] if kubectl_args else None
    if verb in BLOCKED_VERBS:
        raise PermissionError(f"Operation '{verb}' is not allowed in read-only mode")
    if verb not in ALLOWED_VERBS:
        raise ValueError(f"Operation '{verb}' is not recognized")
    return True
```

## Security and Token Hygiene

### Kubeconfig Security

1. **Separate Service Accounts**: Create dedicated service accounts for diagnostic access
2. **Minimal RBAC**: Grant only necessary permissions (list, get, watch)
3. **Token Rotation**: Regularly rotate service account tokens
4. **Audit Logging**: Enable audit logging for all MCP server operations

### RBAC Configuration

Example read-only ClusterRole:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: diagnostic-viewer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "events", "nodes", "namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies", "ingresses"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "volumeattachments"]
  verbs: ["get", "list", "watch"]
```

### Token Management

Best practices for service account tokens:

```bash
# Create service account
kubectl create serviceaccount diagnostic-viewer -n kube-system

# Bind to read-only role
kubectl create clusterrolebinding diagnostic-viewer-binding \
  --clusterrole=diagnostic-viewer \
  --serviceaccount=kube-system:diagnostic-viewer

# Generate time-limited token (Kubernetes 1.24+)
kubectl create token diagnostic-viewer -n kube-system --duration=24h
```

## Common Use Cases

### 1. Automated Pod Diagnostics

When Claude detects a pod issue, the MCP server can:

```python
# MCP server exposes these as callable functions
get_pod_status(namespace, pod_name)
get_pod_events(namespace, pod_name)
get_pod_logs(namespace, pod_name, container)
describe_pod(namespace, pod_name)
```

### 2. Service Endpoint Discovery

For service connectivity issues:

```python
get_service(namespace, service_name)
get_endpoints(namespace, service_name)
list_pods_by_selector(namespace, selector)
```

### 3. Node Health Checks

For cluster-wide diagnostics:

```python
list_nodes()
get_node_conditions(node_name)
get_node_metrics(node_name)
list_pods_on_node(node_name)
```

### 4. Storage Investigation

For PVC/PV issues:

```python
get_pvc(namespace, pvc_name)
get_pv(pv_name)
list_storage_classes()
get_volume_attachments()
```

## Troubleshooting MCP Integration

### Connection Issues

**Symptom**: MCP server fails to connect to cluster

**Diagnosis**:
1. Verify kubeconfig validity: `kubectl cluster-info`
2. Check MCP server logs for authentication errors
3. Validate service account token expiry
4. Confirm network connectivity to API server

**Resolution**:
- Regenerate service account token
- Update kubeconfig in MCP server configuration
- Check firewall rules for API server access

### Permission Errors

**Symptom**: "Forbidden" or "Unauthorized" errors

**Diagnosis**:
1. Check service account permissions: `kubectl auth can-i --list --as=system:serviceaccount:kube-system:diagnostic-viewer`
2. Review RBAC bindings: `kubectl get clusterrolebindings | grep diagnostic`
3. Verify namespace access if using namespaced roles

**Resolution**:
- Update ClusterRole with missing permissions
- Ensure ClusterRoleBinding is correctly configured
- Check if namespace-scoped access requires RoleBinding

### Performance Issues

**Symptom**: Slow response times from MCP server

**Diagnosis**:
1. Check API server latency
2. Review cluster size and resource count
3. Monitor MCP server resource usage

**Resolution**:
- Implement caching in MCP server
- Use label selectors to reduce query scope
- Increase MCP server resource limits
- Consider deploying MCP server closer to cluster

### Data Consistency

**Symptom**: Stale or inconsistent data from MCP server

**Diagnosis**:
1. Verify watch/informer configuration
2. Check for API server throttling
3. Review MCP server cache TTL settings

**Resolution**:
- Reduce cache TTL for frequently changing resources
- Implement cache invalidation on watch events
- Use direct API queries for critical diagnostics

## Best Practices

1. **Separation of Concerns**: Use different service accounts for diagnostics vs. operations
2. **Audit Everything**: Log all MCP server operations for compliance
3. **Fail Secure**: Default to denying operations rather than allowing
4. **Time-Limited Access**: Use short-lived tokens for diagnostic sessions
5. **Namespace Isolation**: Restrict access to specific namespaces when possible
6. **Regular Review**: Periodically audit RBAC permissions and token usage
7. **Documentation**: Maintain clear documentation of MCP server capabilities and limitations

## Additional Resources

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Service Account Token Management](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [kubectl Plugin Development](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/)
