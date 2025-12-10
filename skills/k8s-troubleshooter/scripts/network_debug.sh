#!/usr/bin/env bash
#
# Network Debugging Script
# DNS, endpoints, connectivity, and network policy testing
#
# Usage: ./network_debug.sh SERVICE_NAME NAMESPACE [options]

set -euo pipefail

SERVICE_NAME="${1:-}"
NAMESPACE="${2:-default}"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 SERVICE_NAME NAMESPACE"
    exit 1
fi

echo "=== Service Information ==="
kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" || exit 1

echo ""
echo "=== Endpoints ==="
kubectl get endpoints "$SERVICE_NAME" -n "$NAMESPACE"

echo ""
echo "=== Service Description ==="
kubectl describe svc "$SERVICE_NAME" -n "$NAMESPACE" | grep -A 10 "Selector\|Endpoints\|Port"

echo ""
echo "=== Pods Matching Selector ==="
SELECTOR=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
if [ -n "$SELECTOR" ]; then
    kubectl get pods -n "$NAMESPACE" -l "$SELECTOR" -o wide
else
    echo "No selector defined (headless or external service)"
fi

echo ""
echo "=== DNS Test ==="
kubectl run -it --rm debug-dns-"$(date +%s)" --image=nicolaka/netshoot --restart=Never -- \
    nslookup "$SERVICE_NAME.$NAMESPACE.svc.cluster.local" || echo "DNS test failed"

echo ""
echo "=== Network Policies ==="
kubectl get networkpolicies -n "$NAMESPACE" || echo "No network policies found"

echo ""
echo "Network debugging completed for service: $SERVICE_NAME"
