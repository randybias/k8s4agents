#!/usr/bin/env bash
#
# Cluster Health Check Script
# Performs comprehensive baseline health check of Kubernetes cluster
#
# Portable: Works on both macOS (BSD) and Linux (GNU)
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

# Portable count function - handles wc -l whitespace and empty input
count_lines() {
    local input
    input=$(cat)
    if [ -z "$input" ]; then
        echo 0
    else
        echo "$input" | wc -l | tr -d ' '
    fi
}

# Portable grep count - returns 0 instead of failing when no matches
grep_count() {
    local result
    result=$(grep -c "$@" 2>/dev/null || true)
    # Ensure we only return a single number
    echo "${result:-0}" | head -1 | tr -d ' '
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

    local node_output
    node_output=$(kubectl get nodes --no-headers 2>/dev/null || echo "")

    local node_count ready_count notready_count
    node_count=$(echo "$node_output" | count_lines)
    ready_count=$(echo "$node_output" | grep_count " Ready" || echo 0)
    notready_count=$(echo "$node_output" | grep_count "NotReady" || echo 0)

    print_info "Total nodes: $node_count"
    print_info "Ready: $ready_count"

    if [ "$notready_count" -gt 0 ]; then
        print_error "NotReady nodes: $notready_count"
        kubectl get nodes | grep "NotReady" || true
    else
        print_success "All nodes are Ready"
    fi

    # Check for resource pressure
    local pressure_nodes
    pressure_nodes=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[] | select(.status.conditions[] | select(.type=="DiskPressure" or .type=="MemoryPressure" or .type=="PIDPressure") | select(.status=="True")) | .metadata.name' 2>/dev/null || echo "")

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

    # Check readiness with verbose output for component-level status
    local readyz_verbose
    readyz_verbose=$(kubectl get --raw /readyz?verbose 2>/dev/null || echo "")

    if [ -n "$readyz_verbose" ]; then
        # Check overall readiness status from verbose output
        if echo "$readyz_verbose" | grep -q "readyz check passed"; then
            print_success "All readiness checks passed"
        elif echo "$readyz_verbose" | grep -q "readyz check failed"; then
            print_error "Readiness checks failed"
        fi

        # Parse component-level status in verbose mode
        if [ "$VERBOSE" = true ]; then
            print_info "Component readiness details:"
            # Extract component status lines (format: [+]component or [-]component)
            echo "$readyz_verbose" | grep -E '^\[[-+]\]' | while IFS= read -r line; do
                if echo "$line" | grep -q '^\[+\]'; then
                    # Component is healthy
                    component=$(echo "$line" | sed 's/^\[+\]//')
                    print_info "  ${GREEN}✓${NC} $component"
                elif echo "$line" | grep -q '^\[-\]'; then
                    # Component is failing
                    component=$(echo "$line" | sed 's/^\[-\]//')
                    print_info "  ${RED}✗${NC} $component"
                fi
            done
        else
            # Show only failing components in non-verbose mode
            local failing_components
            failing_components=$(echo "$readyz_verbose" | grep -E '^\[-\]' | sed 's/^\[-\]//' || echo "")
            if [ -n "$failing_components" ]; then
                print_warning "Failing readiness components:"
                echo "$failing_components" | while IFS= read -r component; do
                    print_error "  $component"
                done
            fi
        fi
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
        local pod_output pod_count running

        # Try by label first
        pod_output=$(kubectl get pods -n kube-system -l "component=$component" --no-headers 2>/dev/null || echo "")
        pod_count=$(echo "$pod_output" | { grep -v "^$" || true; } | count_lines)

        if [ "$pod_count" -eq 0 ]; then
            # Try alternative: match by name prefix
            pod_output=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | { grep "^${component}" || true; })
            pod_count=$(echo "$pod_output" | { grep -v "^$" || true; } | count_lines)
        fi

        if [ "$pod_count" -gt 0 ]; then
            running=$(echo "$pod_output" | grep_count "Running")
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
    local coredns_output coredns_count coredns_running
    coredns_output=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null || echo "")
    coredns_count=$(echo "$coredns_output" | { grep -v "^$" || true; } | count_lines)

    if [ "$coredns_count" -eq 0 ]; then
        coredns_output=$(kubectl get pods -n kube-system -l k8s-app=coredns --no-headers 2>/dev/null || echo "")
        coredns_count=$(echo "$coredns_output" | { grep -v "^$" || true; } | count_lines)
    fi

    if [ "$coredns_count" -gt 0 ]; then
        coredns_running=$(echo "$coredns_output" | grep_count "Running")
        if [ "$coredns_running" -eq "$coredns_count" ]; then
            print_success "CoreDNS: $coredns_running/$coredns_count running"
        else
            print_error "CoreDNS: $coredns_running/$coredns_count running"
        fi
    else
        print_error "CoreDNS pods not found"
    fi

    # Check for failed pods in kube-system
    local failed_pods
    failed_pods=$(kubectl get pods -n kube-system --field-selector=status.phase=Failed --no-headers 2>/dev/null | count_lines)
    if [ "$failed_pods" -gt 0 ]; then
        print_warning "Failed pods in kube-system: $failed_pods"
        kubectl get pods -n kube-system --field-selector=status.phase=Failed
    else
        print_success "No failed pods in kube-system"
    fi
}

check_resource_usage() {
    print_header "RESOURCE USAGE"

    if ! kubectl top nodes &> /dev/null 2>&1; then
        print_warning "Metrics server not available or kubectl top not working"
        return
    fi

    # Node resource usage
    print_info "Node resource usage:"
    kubectl top nodes

    # Check for nodes with high resource usage
    local high_cpu_nodes high_mem_nodes
    high_cpu_nodes=$(kubectl top nodes --no-headers 2>/dev/null | awk '{if ($3 ~ /%/ && int($3) > 80) print $1}' || echo "")
    high_mem_nodes=$(kubectl top nodes --no-headers 2>/dev/null | awk '{if ($5 ~ /%/ && int($5) > 80) print $1}' || echo "")

    if [ -n "$high_cpu_nodes" ]; then
        print_warning "Nodes with high CPU usage (>80%): $high_cpu_nodes"
    fi

    if [ -n "$high_mem_nodes" ]; then
        print_warning "Nodes with high memory usage (>80%): $high_mem_nodes"
    fi
}

check_recent_events() {
    print_header "RECENT CLUSTER EVENTS"

    local ns_flag
    if [ -n "$NAMESPACE" ]; then
        ns_flag="-n $NAMESPACE"
    else
        ns_flag="--all-namespaces"
    fi

    # Show last 20 events
    print_info "Last 20 events:"
    kubectl get events $ns_flag --sort-by='.lastTimestamp' 2>/dev/null | tail -20 || echo "No events found"

    # Check for warning events
    local warning_count
    warning_count=$(kubectl get events $ns_flag --field-selector type=Warning --no-headers 2>/dev/null | count_lines)
    if [ "$warning_count" -gt 0 ]; then
        print_warning "Warning events found: $warning_count"
        if [ "$VERBOSE" = true ]; then
            kubectl get events $ns_flag --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
        fi
    else
        print_success "No recent warning events"
    fi
}

check_pod_health() {
    print_header "POD HEALTH"

    local ns_flag
    if [ -n "$NAMESPACE" ]; then
        ns_flag="-n $NAMESPACE"
    else
        ns_flag="--all-namespaces"
    fi

    # Count pods by status
    local total_pods running_pods pending_pods failed_pods
    total_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | count_lines)
    running_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Running --no-headers 2>/dev/null | count_lines)
    pending_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Pending --no-headers 2>/dev/null | count_lines)
    failed_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Failed --no-headers 2>/dev/null | count_lines)

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
    # Note: restart count column position varies based on namespace flag
    local high_restart_pods
    if [ -n "$NAMESPACE" ]; then
        # Single namespace: RESTARTS is column 4
        high_restart_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | awk '{if ($4 ~ /^[0-9]+$/ && $4 > 5) print $1}' || echo "")
    else
        # All namespaces: RESTARTS is column 5 (namespace is column 1)
        high_restart_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | awk '{if ($5 ~ /^[0-9]+$/ && $5 > 5) print $1 "/" $2}' || echo "")
    fi

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
