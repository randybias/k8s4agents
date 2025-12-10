#!/usr/bin/env bash
#
# Storage Check Script
# PVC/PV status, CSI driver health, and storage diagnostics
#
# Usage: ./storage_check.sh PVC_NAME NAMESPACE [options]

set -euo pipefail

PVC_NAME="${1:-}"
NAMESPACE="${2:-default}"

if [ -z "$PVC_NAME" ]; then
    echo "Usage: $0 PVC_NAME NAMESPACE"
    exit 1
fi

echo "=== PVC Status ==="
kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" || exit 1

echo ""
echo "=== PVC Description ==="
kubectl describe pvc "$PVC_NAME" -n "$NAMESPACE"

echo ""
echo "=== Bound PV Details ==="
PV_NAME=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.volumeName}' 2>/dev/null || echo "")
if [ -n "$PV_NAME" ]; then
    kubectl describe pv "$PV_NAME"
else
    echo "PVC not bound to any PV yet"
fi

echo ""
echo "=== StorageClass ==="
SC_NAME=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
if [ -n "$SC_NAME" ]; then
    kubectl describe storageclass "$SC_NAME"
else
    echo "No StorageClass specified"
fi

echo ""
echo "=== CSI Driver Pods ==="
kubectl get pods -n kube-system | grep csi || echo "No CSI driver pods found"

echo ""
echo "=== Volume Attachments ==="
if [ -n "$PV_NAME" ]; then
    kubectl get volumeattachments | grep "$PV_NAME" || echo "No volume attachments found"
fi

echo ""
echo "=== Events ==="
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$PVC_NAME" --sort-by='.lastTimestamp'

echo ""
echo "Storage check completed for PVC: $PVC_NAME"
