#!/usr/bin/env bash
#
# Kubernetes Cluster Comprehensive Assessment Script
# Generates detailed markdown report of cluster health, workloads, and recommendations
#
# Portable: Works on both macOS (BSD) and Linux (GNU)
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

# Data collection functions
get_cluster_name() {
    kubectl config current-context 2>/dev/null || echo "unknown"
}

get_k8s_version() {
    kubectl version --short 2>/dev/null | grep "Server Version" | cut -d: -f2 | xargs || echo "unknown"
}

check_api_health() {
    kubectl get --raw /healthz &>/dev/null && echo "ok" || echo "failed"
}

check_api_ready() {
    kubectl get --raw /readyz &>/dev/null && echo "ok" || echo "failed"
}

check_api_live() {
    kubectl get --raw /livez &>/dev/null && echo "ok" || echo "failed"
}

get_node_summary() {
    kubectl get nodes -o json 2>/dev/null | jq -r '
        .items[] |
        "| \(.metadata.name) | \(.status.conditions[] | select(.type=="Ready") | .status) | \(.status.nodeInfo.kubeletVersion) |"
    ' 2>/dev/null || echo "No node data available"
}

get_node_conditions() {
    kubectl get nodes -o json 2>/dev/null | jq -r '
        .items[] |
        "**\(.metadata.name):**",
        (.status.conditions[] | "- \(.type): \(.status)"),
        ""
    ' 2>/dev/null || echo "No node condition data available"
}

get_control_plane_status() {
    local output=""
    local components=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd")

    for component in "${components[@]}"; do
        local count running pod_output
        pod_output=$(kubectl get pods -n kube-system -l component="$component" --no-headers 2>/dev/null || echo "")
        count=$(echo "$pod_output" | grep -v "^$" | wc -l | tr -d ' ')

        if [ "$count" -gt 0 ]; then
            running=$(echo "$pod_output" | grep -c "Running" 2>/dev/null || echo 0)
            output="${output}- **${component}:** ${running}/${count} running\n"
        else
            # Try matching by name prefix
            pod_output=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep "^${component}" || echo "")
            count=$(echo "$pod_output" | grep -v "^$" | wc -l | tr -d ' ')
            if [ "$count" -gt 0 ]; then
                running=$(echo "$pod_output" | grep -c "Running" 2>/dev/null || echo 0)
                output="${output}- **${component}:** ${running}/${count} running\n"
            fi
        fi
    done

    if [ -z "$output" ]; then
        echo "Control plane components not found (may be external)"
    else
        echo -e "$output"
    fi
}

get_resource_allocation() {
    if kubectl top nodes &>/dev/null 2>&1; then
        kubectl top nodes 2>/dev/null || echo "Metrics not available"
    else
        echo "Metrics server not available"
    fi
}

get_resource_concerns() {
    local pressure_nodes
    pressure_nodes=$(kubectl get nodes -o json 2>/dev/null | jq -r '
        .items[] |
        select(.status.conditions[] | select(.type=="DiskPressure" or .type=="MemoryPressure" or .type=="PIDPressure") | select(.status=="True")) |
        .metadata.name
    ' 2>/dev/null || echo "")

    if [ -n "$pressure_nodes" ]; then
        echo "Nodes with resource pressure:"
        echo "$pressure_nodes"
    else
        echo "No resource pressure detected on any nodes"
    fi
}

get_namespace_count() {
    kubectl get namespaces --no-headers 2>/dev/null | wc -l | tr -d ' '
}

get_pod_counts() {
    local pod_data
    pod_data=$(kubectl get pods --all-namespaces -o json 2>/dev/null)

    local total running pending failed
    total=$(echo "$pod_data" | jq '.items | length' 2>/dev/null || echo 0)
    running=$(echo "$pod_data" | jq '[.items[] | select(.status.phase=="Running")] | length' 2>/dev/null || echo 0)
    pending=$(echo "$pod_data" | jq '[.items[] | select(.status.phase=="Pending")] | length' 2>/dev/null || echo 0)
    failed=$(echo "$pod_data" | jq '[.items[] | select(.status.phase=="Failed")] | length' 2>/dev/null || echo 0)

    echo "$total|$running|$pending|$failed"
}

get_workload_counts() {
    local deployments daemonsets statefulsets
    deployments=$(kubectl get deployments --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    daemonsets=$(kubectl get daemonsets --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    statefulsets=$(kubectl get statefulsets --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "$deployments|$daemonsets|$statefulsets"
}

get_storage_classes() {
    kubectl get storageclass 2>/dev/null || echo "No storage classes found"
}

get_pv_status() {
    local pv_count
    pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pv_count" -gt 0 ]; then
        kubectl get pv 2>/dev/null
    else
        echo "No persistent volumes found"
    fi
}

get_cni_status() {
    # Check for common CNI pods
    local cni_info=""

    if kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | grep -q .; then
        local count running
        count=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l | tr -d ' ')
        running=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | grep -c "Running" || echo 0)
        cni_info="Calico: ${running}/${count} nodes"
    elif kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -q .; then
        local count running
        count=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l | tr -d ' ')
        running=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -c "Running" || echo 0)
        cni_info="Cilium: ${running}/${count} nodes"
    elif kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "weave"; then
        cni_info="Weave detected"
    elif kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "flannel"; then
        cni_info="Flannel detected"
    elif kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "kindnet"; then
        cni_info="kindnet (kind cluster CNI)"
    else
        cni_info="CNI not identified (check kube-system pods)"
    fi

    echo "$cni_info"
}

get_service_discovery() {
    local coredns_count coredns_running
    coredns_count=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$coredns_count" -eq 0 ]; then
        coredns_count=$(kubectl get pods -n kube-system -l k8s-app=coredns --no-headers 2>/dev/null | wc -l | tr -d ' ')
        coredns_running=$(kubectl get pods -n kube-system -l k8s-app=coredns --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    else
        coredns_running=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    fi

    if [ "$coredns_count" -gt 0 ]; then
        echo "CoreDNS: ${coredns_running}/${coredns_count} running"
    else
        echo "CoreDNS pods not found"
    fi
}

get_recent_events() {
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' 2>/dev/null | tail -20 || echo "No events found"
}

get_warning_events() {
    local warnings
    warnings=$(kubectl get events --all-namespaces --field-selector type=Warning --no-headers 2>/dev/null | wc -l | tr -d ' ')

    if [ "$warnings" -gt 0 ]; then
        echo "Found $warnings warning events:"
        echo ""
        kubectl get events --all-namespaces --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -10
    else
        echo "No warning events found"
    fi
}

generate_recommendations() {
    local health="$1"
    local ready="$2"
    local failed_pods="$3"
    local pressure_nodes="$4"

    local high_priority=""
    local medium_priority=""
    local low_priority=""

    # High priority checks
    if [ "$health" != "ok" ]; then
        high_priority="${high_priority}- API server health check failing - investigate immediately\n"
    fi
    if [ "$ready" != "ok" ]; then
        high_priority="${high_priority}- API server readiness check failing - cluster may be degraded\n"
    fi
    if [ "$failed_pods" -gt 0 ]; then
        high_priority="${high_priority}- ${failed_pods} failed pods detected - investigate and clean up\n"
    fi

    # Medium priority checks
    if [ -n "$pressure_nodes" ]; then
        medium_priority="${medium_priority}- Nodes with resource pressure detected - review resource allocation\n"
    fi

    # Low priority (general recommendations)
    low_priority="- Review resource requests and limits for all workloads\n- Ensure pod disruption budgets are configured for critical services\n- Verify backup and disaster recovery procedures are in place"

    if [ -z "$high_priority" ]; then
        high_priority="No high priority issues detected"
    fi
    if [ -z "$medium_priority" ]; then
        medium_priority="No medium priority issues detected"
    fi

    echo "HIGH:${high_priority}|MEDIUM:${medium_priority}|LOW:${low_priority}"
}

generate_report() {
    local output_file="$1"

    print_status "Collecting cluster data..."

    # Gather all data upfront
    local cluster_name k8s_version
    cluster_name=$(get_cluster_name)
    k8s_version=$(get_k8s_version)

    local health ready live
    health=$(check_api_health)
    ready=$(check_api_ready)
    live=$(check_api_live)

    local health_icon ready_icon live_icon
    health_icon=$([ "$health" = "ok" ] && echo "OK" || echo "FAILED")
    ready_icon=$([ "$ready" = "ok" ] && echo "OK" || echo "FAILED")
    live_icon=$([ "$live" = "ok" ] && echo "OK" || echo "FAILED")

    local overall_health="HEALTHY"
    if [ "$health" != "ok" ] || [ "$ready" != "ok" ]; then
        overall_health="DEGRADED"
    fi

    print_status "Analyzing nodes..."
    local node_summary node_conditions control_plane_status
    node_summary=$(get_node_summary)
    node_conditions=$(get_node_conditions)
    control_plane_status=$(get_control_plane_status)

    print_status "Analyzing resources..."
    local resource_allocation resource_concerns
    resource_allocation=$(get_resource_allocation)
    resource_concerns=$(get_resource_concerns)

    print_status "Analyzing workloads..."
    local namespace_count pod_counts workload_counts
    namespace_count=$(get_namespace_count)
    pod_counts=$(get_pod_counts)
    workload_counts=$(get_workload_counts)

    local total_pods running_pods pending_pods failed_pods
    total_pods=$(echo "$pod_counts" | cut -d'|' -f1)
    running_pods=$(echo "$pod_counts" | cut -d'|' -f2)
    pending_pods=$(echo "$pod_counts" | cut -d'|' -f3)
    failed_pods=$(echo "$pod_counts" | cut -d'|' -f4)

    local deployments daemonsets statefulsets
    deployments=$(echo "$workload_counts" | cut -d'|' -f1)
    daemonsets=$(echo "$workload_counts" | cut -d'|' -f2)
    statefulsets=$(echo "$workload_counts" | cut -d'|' -f3)

    local failed_pods_status
    if [ "$failed_pods" -gt 0 ]; then
        failed_pods_status="WARNING: $failed_pods failed pods detected"
    else
        failed_pods_status="No failed pods"
    fi

    print_status "Analyzing storage..."
    local storage_classes pv_status
    storage_classes=$(get_storage_classes)
    pv_status=$(get_pv_status)

    print_status "Analyzing networking..."
    local cni_status service_discovery
    cni_status=$(get_cni_status)
    service_discovery=$(get_service_discovery)

    print_status "Collecting events..."
    local recent_events warning_events
    recent_events=$(get_recent_events)
    warning_events=$(get_warning_events)

    print_status "Generating recommendations..."
    local pressure_nodes
    pressure_nodes=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[] | select(.status.conditions[] | select(.type=="DiskPressure" or .type=="MemoryPressure" or .type=="PIDPressure") | select(.status=="True")) | .metadata.name' 2>/dev/null || echo "")

    local recommendations
    recommendations=$(generate_recommendations "$health" "$ready" "$failed_pods" "$pressure_nodes")

    local high_priority medium_priority low_priority
    high_priority=$(echo "$recommendations" | sed 's/.*HIGH:\(.*\)|MEDIUM:.*/\1/')
    medium_priority=$(echo "$recommendations" | sed 's/.*MEDIUM:\(.*\)|LOW:.*/\1/')
    low_priority=$(echo "$recommendations" | sed 's/.*LOW:\(.*\)/\1/')

    local conclusion
    if [ "$overall_health" = "HEALTHY" ]; then
        conclusion="The cluster is operating normally. Continue to monitor for any issues and follow the low-priority recommendations for ongoing maintenance."
    else
        conclusion="The cluster requires attention. Please address the high-priority recommendations immediately and review medium-priority items."
    fi

    local report_date
    report_date=$(date '+%Y-%m-%d %H:%M:%S %Z')

    print_status "Writing report: $output_file"

    # Generate the full report using heredoc (portable across BSD/GNU)
    cat > "$output_file" << EOF
# Kubernetes Cluster Assessment Report

## Executive Summary

**Cluster Name:** ${cluster_name}
**Kubernetes Version:** ${k8s_version}
**Assessment Date:** ${report_date}
**Overall Health:** ${overall_health}

---

## 1. Control Plane Health

### API Server Status
- **Health:** ${health_icon}
- **Readiness:** ${ready_icon}
- **Liveness:** ${live_icon}
- **Version:** ${k8s_version}

### Control Plane Components
${control_plane_status}

---

## 2. Node Health

### Node Summary
| Name | Ready | Version |
|------|-------|---------|
${node_summary}

### Node Conditions
${node_conditions}

---

## 3. Resource Allocation and Capacity

### Node Resource Allocation
\`\`\`
${resource_allocation}
\`\`\`

### Concern: Resource Overcommitment
${resource_concerns}

---

## 4. Workload Status

### Namespace Overview
${namespace_count} namespaces active

### Pod Status
- **Total Pods:** ${total_pods}
- **Running:** ${running_pods}
- **Pending:** ${pending_pods}
- **Failed:** ${failed_pods}

### Workload Distribution
- **Deployments:** ${deployments}
- **DaemonSets:** ${daemonsets}
- **StatefulSets:** ${statefulsets}

---

## 5. Storage Infrastructure

### Storage Classes
\`\`\`
${storage_classes}
\`\`\`

### Persistent Volumes
\`\`\`
${pv_status}
\`\`\`

---

## 6. Network Infrastructure

### CNI (Container Network Interface)
${cni_status}

### Service Discovery
${service_discovery}

---

## 7. Recent Events and Alerts

### Recent Events (Last 20)
\`\`\`
${recent_events}
\`\`\`

### Warnings
${warning_events}

### Failed Pods
${failed_pods_status}

---

## 8. Recommendations

### High Priority
$(echo -e "$high_priority")

### Medium Priority
$(echo -e "$medium_priority")

### Low Priority
$(echo -e "$low_priority")

---

## Conclusion

${conclusion}

---

*Report generated by k8s-troubleshooter skill on ${report_date}*
EOF

    print_status "Report generated successfully: $output_file"
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
