#!/usr/bin/env bash
#
# Pod Diagnostics Script
# Comprehensive pod troubleshooting with status, events, logs, and resource analysis
#
# Usage: ./pod_diagnostics.sh POD_NAME NAMESPACE [options]
# Options:
#   -c, --container CONTAINER  Specific container name
#   -v, --verbose              Verbose output
#   -l, --logs                 Show container logs
#   -p, --previous             Show previous container logs
#   -h, --help                 Show this help message

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
POD_NAME=""
NAMESPACE=""
CONTAINER=""
VERBOSE=false
SHOW_LOGS=false
SHOW_PREVIOUS=false

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}--- $1 ---${NC}"
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
    echo "  $1"
}

check_pod_status() {
    print_header "POD STATUS"

    # Get pod phase
    local phase=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    print_info "Phase: $phase"

    # Get pod conditions
    echo ""
    print_section "Pod Conditions"
    kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.status.conditions[] | "\(.type): \(.status) (\(.reason // "N/A"))"'

    # Get pod details
    echo ""
    print_section "Pod Details"
    kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o wide

    # Get restart count
    local restart_count=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    if [ "$restart_count" -gt 5 ]; then
        print_warning "High restart count: $restart_count"
    else
        print_info "Restart count: $restart_count"
    fi
}

check_container_status() {
    print_header "CONTAINER STATUS"

    # List all containers
    local containers=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}')
    print_info "Containers: $containers"

    # Get container statuses
    echo ""
    local container_statuses=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.status.containerStatuses[]? // empty')

    if [ -n "$container_statuses" ]; then
        kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.status.containerStatuses[] | "Container: \(.name)\n  State: \(.state | keys[0])\n  Ready: \(.ready)\n  Restart Count: \(.restartCount)\n  Image: \(.image)"'

        # Check for terminated state
        local terminated=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.status.containerStatuses[]? | select(.state.terminated != null) | "\(.name): \(.state.terminated.reason) (exit code: \(.state.terminated.exitCode))"')

        if [ -n "$terminated" ]; then
            echo ""
            print_warning "Terminated containers:"
            echo "$terminated"
        fi

        # Check last termination state
        local last_terminated=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.status.containerStatuses[]? | select(.lastState.terminated != null) | "\(.name): \(.lastState.terminated.reason) (exit code: \(.lastState.terminated.exitCode)) at \(.lastState.terminated.finishedAt)"')

        if [ -n "$last_terminated" ]; then
            echo ""
            print_warning "Last termination state:"
            echo "$last_terminated"
        fi
    else
        print_warning "No container statuses available yet"
    fi

    # Check init containers
    local init_containers=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null || echo "")

    if [ -n "$init_containers" ]; then
        echo ""
        print_section "Init Containers"
        print_info "Init containers: $init_containers"

        local init_status=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.status.initContainerStatuses[]? | "Init Container: \(.name)\n  State: \(.state | keys[0])\n  Ready: \(.ready)"')

        if [ -n "$init_status" ]; then
            echo "$init_status"
        fi
    fi
}

check_events() {
    print_header "EVENTS"

    local events=$(kubectl get events -n "$NAMESPACE" \
        --field-selector involvedObject.name="$POD_NAME" \
        --sort-by='.lastTimestamp' 2>/dev/null)

    if [ -n "$events" ]; then
        echo "$events"

        # Check for warning events
        local warnings=$(kubectl get events -n "$NAMESPACE" \
            --field-selector involvedObject.name="$POD_NAME",type=Warning \
            --no-headers 2>/dev/null | wc -l || echo 0)

        if [ "$warnings" -gt 0 ]; then
            echo ""
            print_warning "$warnings warning events found"
        fi
    else
        print_info "No events found for this pod"
    fi
}

check_resources() {
    print_header "RESOURCE CONFIGURATION"

    # Get resource requests and limits
    echo ""
    print_section "Resource Requests and Limits"
    kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.containers[] | "Container: \(.name)\n  Requests:\n    CPU: \(.resources.requests.cpu // "not set")\n    Memory: \(.resources.requests.memory // "not set")\n  Limits:\n    CPU: \(.resources.limits.cpu // "not set")\n    Memory: \(.resources.limits.memory // "not set")"'

    # Get QoS class
    local qos=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.qosClass}')
    print_info "QoS Class: $qos"

    # Try to get current resource usage
    if command -v kubectl &> /dev/null && kubectl top pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
        echo ""
        print_section "Current Resource Usage"
        kubectl top pod "$POD_NAME" -n "$NAMESPACE" --containers
    fi
}

check_volumes() {
    print_header "VOLUMES AND MOUNTS"

    # Check volumes
    local volumes=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.volumes[]? | "Volume: \(.name)\n  Type: \(. | keys[1])"')

    if [ -n "$volumes" ]; then
        echo "$volumes"

        # Check for PVCs
        local pvcs=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}' 2>/dev/null || echo "")

        if [ -n "$pvcs" ]; then
            echo ""
            print_section "PVC Status"
            for pvc in $pvcs; do
                kubectl get pvc "$pvc" -n "$NAMESPACE" 2>/dev/null || print_warning "PVC $pvc not found"
            done
        fi
    else
        print_info "No volumes configured"
    fi

    # Check volume mounts
    echo ""
    print_section "Volume Mounts"
    kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.containers[] | "Container: \(.name)\n  Mounts:" , (.volumeMounts[]? | "    \(.name) -> \(.mountPath)")' || print_info "No volume mounts"
}

check_probes() {
    print_header "HEALTH PROBES"

    # Check liveness probe
    local liveness=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.containers[] | "Container: \(.name)\n  Liveness Probe: \(if .livenessProbe then "configured" else "not configured" end)"')

    echo "$liveness"

    if [ "$VERBOSE" = true ]; then
        kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.containers[] | select(.livenessProbe != null) | "  \(.name) liveness: \(.livenessProbe)"'
    fi

    # Check readiness probe
    echo ""
    local readiness=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.containers[] | "Container: \(.name)\n  Readiness Probe: \(if .readinessProbe then "configured" else "not configured" end)"')

    echo "$readiness"

    if [ "$VERBOSE" = true ]; then
        kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.containers[] | select(.readinessProbe != null) | "  \(.name) readiness: \(.readinessProbe)"'
    fi

    # Check startup probe
    echo ""
    local startup=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o json | jq -r '.spec.containers[] | "Container: \(.name)\n  Startup Probe: \(if .startupProbe then "configured" else "not configured" end)"')

    echo "$startup"
}

check_network() {
    print_header "NETWORK CONFIGURATION"

    # Get pod IP
    local pod_ip=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.podIP}')
    print_info "Pod IP: ${pod_ip:-not assigned}"

    # Get host IP
    local host_ip=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.hostIP}')
    print_info "Host IP: $host_ip"

    # Get node name
    local node_name=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
    print_info "Node: $node_name"

    # Check DNS policy
    local dns_policy=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.dnsPolicy}')
    print_info "DNS Policy: $dns_policy"

    # Check host network
    local host_network=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.hostNetwork}')
    if [ "$host_network" = "true" ]; then
        print_warning "Pod using host network"
    fi
}

show_logs() {
    print_header "CONTAINER LOGS"

    local target_container="$CONTAINER"

    if [ -z "$target_container" ]; then
        # Get first container if not specified
        target_container=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].name}')
        print_info "Container: $target_container (default)"
    else
        print_info "Container: $target_container"
    fi

    echo ""

    if [ "$SHOW_PREVIOUS" = true ]; then
        print_section "Previous Container Logs (last 100 lines)"
        kubectl logs "$POD_NAME" -n "$NAMESPACE" -c "$target_container" --previous --tail=100 2>/dev/null || print_warning "No previous logs available"
    else
        print_section "Current Container Logs (last 100 lines)"
        kubectl logs "$POD_NAME" -n "$NAMESPACE" -c "$target_container" --tail=100 2>/dev/null || print_warning "No logs available"
    fi
}

show_usage() {
    echo "Usage: $0 POD_NAME NAMESPACE [options]"
    echo ""
    echo "Options:"
    echo "  -c, --container CONTAINER  Specific container name"
    echo "  -v, --verbose              Verbose output"
    echo "  -l, --logs                 Show container logs"
    echo "  -p, --previous             Show previous container logs"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 my-pod default -l -v"
    echo "  $0 my-pod default -c app-container -p"
}

# Parse command line arguments
if [ $# -lt 2 ]; then
    show_usage
    exit 1
fi

POD_NAME="$1"
NAMESPACE="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--logs)
            SHOW_LOGS=true
            shift
            ;;
        -p|--previous)
            SHOW_PREVIOUS=true
            SHOW_LOGS=true
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
    echo "Pod Diagnostics: $POD_NAME (namespace: $NAMESPACE)"
    echo "===================================================="

    # Check if pod exists
    if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_error "Pod '$POD_NAME' not found in namespace '$NAMESPACE'"
        exit 1
    fi

    check_pod_status
    check_container_status
    check_events
    check_resources
    check_volumes
    check_probes
    check_network

    if [ "$SHOW_LOGS" = true ]; then
        show_logs
    fi

    echo ""
    print_header "DIAGNOSTIC SUMMARY"
    echo "Review the information above to identify pod issues."
    echo "Use -l flag to show logs, -p for previous container logs."
}

main
