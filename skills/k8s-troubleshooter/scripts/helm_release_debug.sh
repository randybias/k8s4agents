#!/usr/bin/env bash
#
# Helm Release Debug Script
# Helm release status, history, and troubleshooting
#
# Usage: ./helm_release_debug.sh RELEASE_NAME NAMESPACE [options]

set -euo pipefail

RELEASE_NAME="${1:-}"
NAMESPACE="${2:-default}"

if [ -z "$RELEASE_NAME" ]; then
    echo "Usage: $0 RELEASE_NAME NAMESPACE"
    exit 1
fi

echo "=== Helm Release Status ==="
helm status "$RELEASE_NAME" -n "$NAMESPACE" || exit 1

echo ""
echo "=== Release History ==="
helm history "$RELEASE_NAME" -n "$NAMESPACE"

echo ""
echo "=== Current Release Values ==="
helm get values "$RELEASE_NAME" -n "$NAMESPACE"

echo ""
echo "=== Deployed Resources ==="
helm get manifest "$RELEASE_NAME" -n "$NAMESPACE" | kubectl get -f - -o wide 2>/dev/null || echo "Some resources may not exist"

echo ""
echo "=== Recent Events ==="
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20

echo ""
echo "=== Helm Secrets ==="
kubectl get secrets -n "$NAMESPACE" -l owner=helm,name="$RELEASE_NAME" || echo "No helm secrets found"

echo ""
echo "=== Pods Status ==="
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance="$RELEASE_NAME" 2>/dev/null || echo "No pods found with standard Helm labels"

echo ""
echo "Helm release debugging completed for: $RELEASE_NAME"
