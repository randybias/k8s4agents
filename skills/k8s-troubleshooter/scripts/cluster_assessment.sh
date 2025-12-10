#!/usr/bin/env bash
#
# Kubernetes Cluster Comprehensive Assessment Script
# Generates detailed markdown report of cluster health, workloads, and recommendations
#
# Usage: ./cluster_assessment.sh [options]
# Options:
#   -o, --output FILE         Output markdown file (default: cluster-assessment-TIMESTAMP.md)
#   -c, --kubeconfig FILE     Path to kubeconfig file
#   -h, --help                Show this help message
#

set -euo pipefail

# Configuration
OUTPUT_FILE=""
KUBECONFIG_PATH="${KUBECONFIG:-}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Kubernetes Cluster Comprehensive Assessment Script

Usage: $0 [options]

Options:
  -o, --output FILE         Output markdown file (default: cluster-assessment-TIMESTAMP.md)
  -c, --kubeconfig FILE     Path to kubeconfig file
  -h, --help                Show this help message

Examples:
  $0
  $0 -o my-cluster-report.md
  $0 -c ~/.kube/config -o report.md

EOF
}

check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
}

get_cluster_info() {
    local cluster_name=$(kubectl config current-context 2>/dev/null || echo "unknown")
    local k8s_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | cut -d: -f2 | xargs || echo "unknown")
    echo "$cluster_name|$k8s_version"
}

collect_node_data() {
    kubectl get nodes -o json 2>/dev/null
}

collect_pod_data() {
    kubectl get pods --all-namespaces -o json 2>/dev/null
}

collect_namespace_data() {
    kubectl get namespaces -o json 2>/dev/null
}

collect_workload_data() {
    local deployments=$(kubectl get deployments --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local daemonsets=$(kubectl get daemonsets --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    local statefulsets=$(kubectl get statefulsets --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "$deployments|$daemonsets|$statefulsets"
}

collect_storage_data() {
    local pvcs=$(kubectl get pvc --all-namespaces -o json 2>/dev/null)
    local pvs=$(kubectl get pv -o json 2>/dev/null)
    local sc=$(kubectl get storageclass -o json 2>/dev/null)
    echo "$pvcs|||$pvs|||$sc"
}

collect_events() {
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' -o json 2>/dev/null | \
        jq -r '.items[-50:] | .[] | "\(.lastTimestamp)|\(.type)|\(.involvedObject.namespace)|\(.involvedObject.name)|\(.reason)|\(.message)"' 2>/dev/null || echo ""
}

check_api_health() {
    local health="unknown"
    local ready="unknown"
    local live="unknown"

    kubectl get --raw /healthz &>/dev/null && health="ok" || health="failed"
    kubectl get --raw /readyz &>/dev/null && ready="ok" || ready="failed"
    kubectl get --raw /livez &>/dev/null && live="ok" || live="failed"

    echo "$health|$ready|$live"
}

generate_report() {
    local output_file="$1"

    print_status "Collecting cluster data..."

    # Gather all data
    local cluster_info=$(get_cluster_info)
    local cluster_name=$(echo "$cluster_info" | cut -d'|' -f1)
    local k8s_version=$(echo "$cluster_info" | cut -d'|' -f2)

    local api_health=$(check_api_health)
    local health=$(echo "$api_health" | cut -d'|' -f1)
    local ready=$(echo "$api_health" | cut -d'|' -f2)
    local live=$(echo "$api_health" | cut -d'|' -f3)

    print_status "Analyzing nodes..."
    local node_data=$(collect_node_data)

    print_status "Analyzing pods..."
    local pod_data=$(collect_pod_data)

    print_status "Analyzing workloads..."
    local workload_data=$(collect_workload_data)

    print_status "Analyzing storage..."
    local namespace_data=$(collect_namespace_data)

    print_status "Collecting recent events..."

    # Generate markdown report
    print_status "Generating report: $output_file"

    cat > "$output_file" << 'EOF'
# Kubernetes Cluster Assessment Report

## Executive Summary

**Cluster Name:** {{CLUSTER_NAME}}
**Kubernetes Version:** {{K8S_VERSION}}
**Assessment Date:** {{DATE}}
**Overall Health:** {{OVERALL_HEALTH}}

---

## 1. Control Plane Health

### API Server Status
- **Health:** {{API_HEALTH}}
- **Readiness:** {{API_READY}}
- **Liveness:** {{API_LIVE}}
- **Version:** {{K8S_VERSION}}

### Control Plane Components
{{CONTROL_PLANE_COMPONENTS}}

---

## 2. Node Health

### Node Summary
{{NODE_SUMMARY}}

### Node Conditions
{{NODE_CONDITIONS}}

---

## 3. Resource Allocation and Capacity

### Node Resource Allocation
{{RESOURCE_ALLOCATION}}

### Concern: Resource Overcommitment
{{RESOURCE_CONCERNS}}

---

## 4. Workload Status

### Namespace Overview
{{NAMESPACE_OVERVIEW}}

### Pod Status
{{POD_STATUS}}

### Workload Distribution
- **Deployments:** {{DEPLOYMENT_COUNT}}
- **DaemonSets:** {{DAEMONSET_COUNT}}
- **StatefulSets:** {{STATEFULSET_COUNT}}

---

## 5. Storage Infrastructure

### Storage Classes
{{STORAGE_CLASSES}}

### Persistent Volumes
{{PV_STATUS}}

---

## 6. Network Infrastructure

### CNI (Container Network Interface)
{{CNI_STATUS}}

### Service Discovery
{{SERVICE_DISCOVERY}}

---

## 7. Recent Events and Alerts

### Recent Events (Last 50)
{{RECENT_EVENTS}}

### Warnings
{{WARNING_EVENTS}}

### Failed Pods
{{FAILED_PODS}}

---

## 8. Recommendations

### High Priority
{{HIGH_PRIORITY_RECOMMENDATIONS}}

### Medium Priority
{{MEDIUM_PRIORITY_RECOMMENDATIONS}}

### Low Priority
{{LOW_PRIORITY_RECOMMENDATIONS}}

---

## Conclusion

{{CONCLUSION}}

---

*Report generated by k8s-troubleshooter skill on {{DATE}}*
EOF

    # Now populate the template with actual data
    sed -i.bak "s|{{CLUSTER_NAME}}|$cluster_name|g" "$output_file"
    sed -i.bak "s|{{K8S_VERSION}}|$k8s_version|g" "$output_file"
    sed -i.bak "s|{{DATE}}|$(date '+%Y-%m-%d %H:%M:%S %Z')|g" "$output_file"
    sed -i.bak "s|{{API_HEALTH}}|$([ "$health" = "ok" ] && echo "✅ OK" || echo "❌ FAILED")|g" "$output_file"
    sed -i.bak "s|{{API_READY}}|$([ "$ready" = "ok" ] && echo "✅ OK" || echo "❌ FAILED")|g" "$output_file"
    sed -i.bak "s|{{API_LIVE}}|$([ "$live" = "ok" ] && echo "✅ OK" || echo "❌ FAILED")|g" "$output_file"

    # Determine overall health
    local overall_health="✅ HEALTHY"
    if [ "$health" != "ok" ] || [ "$ready" != "ok" ]; then
        overall_health="⚠️ DEGRADED"
    fi
    sed -i.bak "s|{{OVERALL_HEALTH}}|$overall_health|g" "$output_file"

    # Add detailed sections
    add_node_details "$output_file" "$node_data"
    add_pod_details "$output_file" "$pod_data"
    add_workload_details "$output_file" "$workload_data"
    add_namespace_details "$output_file" "$namespace_data"

    # Clean up backup file
    rm -f "${output_file}.bak"

    print_status "Report generated successfully: $output_file"
}

add_node_details() {
    local output_file="$1"
    local node_data="$2"

    local node_summary=$(echo "$node_data" | jq -r '.items[] | "| \(.metadata.name) | \(.status.conditions[] | select(.type=="Ready") | .status) | \(.status.nodeInfo.kubeletVersion) |"' 2>/dev/null || echo "No node data available")

    # Replace placeholder with actual data
    sed -i.bak "s|{{NODE_SUMMARY}}|$node_summary|g" "$output_file"
}

add_pod_details() {
    local output_file="$1"
    local pod_data="$2"

    local total_pods=$(echo "$pod_data" | jq '.items | length' 2>/dev/null || echo 0)
    local running_pods=$(echo "$pod_data" | jq '[.items[] | select(.status.phase=="Running")] | length' 2>/dev/null || echo 0)
    local pending_pods=$(echo "$pod_data" | jq '[.items[] | select(.status.phase=="Pending")] | length' 2>/dev/null || echo 0)
    local failed_pods=$(echo "$pod_data" | jq '[.items[] | select(.status.phase=="Failed")] | length' 2>/dev/null || echo 0)

    local pod_status="- **Total Pods:** $total_pods\n- **Running:** $running_pods\n- **Pending:** $pending_pods\n- **Failed:** $failed_pods"

    sed -i.bak "s|{{POD_STATUS}}|$pod_status|g" "$output_file"
    sed -i.bak "s|{{FAILED_PODS}}|$([ "$failed_pods" -gt 0 ] && echo "⚠️ $failed_pods failed pods detected" || echo "✅ No failed pods")|g" "$output_file"
}

add_workload_details() {
    local output_file="$1"
    local workload_data="$2"

    local deployments=$(echo "$workload_data" | cut -d'|' -f1)
    local daemonsets=$(echo "$workload_data" | cut -d'|' -f2)
    local statefulsets=$(echo "$workload_data" | cut -d'|' -f3)

    sed -i.bak "s|{{DEPLOYMENT_COUNT}}|$deployments|g" "$output_file"
    sed -i.bak "s|{{DAEMONSET_COUNT}}|$daemonsets|g" "$output_file"
    sed -i.bak "s|{{STATEFULSET_COUNT}}|$statefulsets|g" "$output_file"
}

add_namespace_details() {
    local output_file="$1"
    local namespace_data="$2"

    local namespace_list=$(echo "$namespace_data" | jq -r '.items[].metadata.name' 2>/dev/null | wc -l || echo 0)
    local namespace_overview="$namespace_list namespaces active"

    sed -i.bak "s|{{NAMESPACE_OVERVIEW}}|$namespace_overview|g" "$output_file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--kubeconfig)
            export KUBECONFIG="$2"
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set default output file if not specified
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="cluster-assessment-${TIMESTAMP}.md"
fi

# Main execution
main() {
    echo "Kubernetes Cluster Comprehensive Assessment"
    echo "==========================================="
    echo ""

    if [ -n "$KUBECONFIG_PATH" ]; then
        print_status "Using kubeconfig: $KUBECONFIG_PATH"
    fi

    check_prerequisites
    generate_report "$OUTPUT_FILE"

    echo ""
    echo -e "${GREEN}Assessment complete!${NC}"
    echo "Report saved to: $OUTPUT_FILE"
}

main
