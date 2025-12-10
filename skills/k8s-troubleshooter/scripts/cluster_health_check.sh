#!/usr/bin/env bash
#
# Cluster Health Check Script
# Performs comprehensive baseline health check of Kubernetes cluster
#
# Usage: ./cluster_health_check.sh [options]
# Options:
#   -n, --namespace NAMESPACE  Check specific namespace (default: all)
#   -v, --verbose             Verbose output
#   -h, --help                Show this help message

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE=""
VERBOSE=false

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    if [ "$VERBOSE" = true ]; then
        echo "  $1"
    fi
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

    print_success "Connected to Kubernetes cluster"
}

check_nodes() {
    print_header "NODE STATUS"

    local node_count=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
    local ready_count=$(kubectl get nodes --no-headers | grep -c "Ready" || echo 0)
    local notready_count=$(kubectl get nodes --no-headers | grep -c "NotReady" || echo 0)

    print_info "Total nodes: $node_count"
    print_info "Ready: $ready_count"

    if [ "$notready_count" -gt 0 ]; then
        print_error "NotReady nodes: $notready_count"
        kubectl get nodes | grep "NotReady"
    else
        print_success "All nodes are Ready"
    fi

    # Check for resource pressure
    local pressure_nodes=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="DiskPressure" or .type=="MemoryPressure" or .type=="PIDPressure") | select(.status=="True")) | .metadata.name' 2>/dev/null || echo "")

    if [ -n "$pressure_nodes" ]; then
        print_warning "Nodes with resource pressure detected:"
        echo "$pressure_nodes"
    else
        print_success "No resource pressure on nodes"
    fi
}

check_control_plane() {
    print_header "CONTROL PLANE HEALTH"

    # Check API server health
    if kubectl get --raw /healthz &> /dev/null; then
        print_success "API server is healthy"
    else
        print_error "API server health check failed"
    fi

    # Check readiness
    if kubectl get --raw /readyz &> /dev/null; then
        print_success "API server is ready"
    else
        print_warning "API server readiness check failed"
    fi

    # Check liveness
    if kubectl get --raw /livez &> /dev/null; then
        print_success "API server is alive"
    else
        print_warning "API server liveness check failed"
    fi
}

check_system_pods() {
    print_header "SYSTEM PODS STATUS"

    # Check critical kube-system pods
    local critical_components=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd" "kube-proxy")

    for component in "${critical_components[@]}"; do
        local pod_count=$(kubectl get pods -n kube-system -l component=$component --no-headers 2>/dev/null | wc -l || echo 0)

        if [ "$pod_count" -eq 0 ]; then
            # Try alternative label
            pod_count=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "^$component" || echo 0)
        fi

        if [ "$pod_count" -gt 0 ]; then
            local running=$(kubectl get pods -n kube-system -l component=$component --no-headers 2>/dev/null | grep -c "Running" || kubectl get pods -n kube-system --no-headers 2>/dev/null | grep "^$component" | grep -c "Running" || echo 0)
            if [ "$running" -eq "$pod_count" ]; then
                print_success "$component: $running/$pod_count running"
            else
                print_error "$component: $running/$pod_count running"
            fi
        else
            print_info "$component: not found (may be external)"
        fi
    done

    # Check CoreDNS
    local coredns_count=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$coredns_count" -eq 0 ]; then
        coredns_count=$(kubectl get pods -n kube-system -l k8s-app=coredns --no-headers 2>/dev/null | wc -l || echo 0)
    fi

    if [ "$coredns_count" -gt 0 ]; then
        local coredns_running=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || kubectl get pods -n kube-system -l k8s-app=coredns --no-headers 2>/dev/null | grep -c "Running" || echo 0)
        if [ "$coredns_running" -eq "$coredns_count" ]; then
            print_success "CoreDNS: $coredns_running/$coredns_count running"
        else
            print_error "CoreDNS: $coredns_running/$coredns_count running"
        fi
    else
        print_error "CoreDNS pods not found"
    fi

    # Check for failed pods in kube-system
    local failed_pods=$(kubectl get pods -n kube-system --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    if [ "$failed_pods" -gt 0 ]; then
        print_warning "Failed pods in kube-system: $failed_pods"
        kubectl get pods -n kube-system --field-selector=status.phase=Failed
    else
        print_success "No failed pods in kube-system"
    fi
}

check_resource_usage() {
    print_header "RESOURCE USAGE"

    if ! command -v kubectl &> /dev/null || ! kubectl top nodes &> /dev/null; then
        print_warning "Metrics server not available or kubectl top not working"
        return
    fi

    # Node resource usage
    print_info "Node resource usage:"
    kubectl top nodes

    # Check for nodes with high resource usage
    local high_cpu_nodes=$(kubectl top nodes --no-headers 2>/dev/null | awk '{if ($3 ~ /%/ && int($3) > 80) print $1}' || echo "")
    local high_mem_nodes=$(kubectl top nodes --no-headers 2>/dev/null | awk '{if ($5 ~ /%/ && int($5) > 80) print $1}' || echo "")

    if [ -n "$high_cpu_nodes" ]; then
        print_warning "Nodes with high CPU usage (>80%): $high_cpu_nodes"
    fi

    if [ -n "$high_mem_nodes" ]; then
        print_warning "Nodes with high memory usage (>80%): $high_mem_nodes"
    fi
}

check_recent_events() {
    print_header "RECENT CLUSTER EVENTS"

    local ns_flag=""
    if [ -n "$NAMESPACE" ]; then
        ns_flag="-n $NAMESPACE"
    else
        ns_flag="--all-namespaces"
    fi

    # Show last 20 events
    print_info "Last 20 events:"
    kubectl get events $ns_flag --sort-by='.lastTimestamp' | tail -20

    # Check for warning events
    local warning_count=$(kubectl get events $ns_flag --field-selector type=Warning --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    if [ "$warning_count" -gt 0 ]; then
        print_warning "Warning events found: $warning_count"
        if [ "$VERBOSE" = true ]; then
            kubectl get events $ns_flag --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10
        fi
    else
        print_success "No recent warning events"
    fi
}

check_pod_health() {
    print_header "POD HEALTH"

    local ns_flag=""
    if [ -n "$NAMESPACE" ]; then
        ns_flag="-n $NAMESPACE"
    else
        ns_flag="--all-namespaces"
    fi

    # Count pods by status
    local total_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    local running_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    local pending_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    local failed_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo 0)

    print_info "Total pods: $total_pods"
    print_info "Running: $running_pods"

    if [ "$pending_pods" -gt 0 ]; then
        print_warning "Pending pods: $pending_pods"
        if [ "$VERBOSE" = true ]; then
            kubectl get pods $ns_flag --field-selector=status.phase=Pending
        fi
    fi

    if [ "$failed_pods" -gt 0 ]; then
        print_error "Failed pods: $failed_pods"
        if [ "$VERBOSE" = true ]; then
            kubectl get pods $ns_flag --field-selector=status.phase=Failed
        fi
    fi

    # Check for pods with high restart count
    local high_restart_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | awk '{if ($4 > 5) print $1}' || echo "")
    if [ -n "$high_restart_pods" ]; then
        print_warning "Pods with high restart count (>5):"
        echo "$high_restart_pods"
    fi
}

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE  Check specific namespace (default: all)"
    echo "  -v, --verbose             Verbose output"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -n production -v"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
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

# Main execution
main() {
    echo "Kubernetes Cluster Health Check"
    echo "================================"
    echo ""

    check_prerequisites
    check_nodes
    check_control_plane
    check_system_pods
    check_resource_usage
    check_recent_events
    check_pod_health

    echo ""
    print_header "SUMMARY"
    echo "Health check completed."
    echo "Review any warnings or errors above."
}

main
