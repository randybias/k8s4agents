#!/usr/bin/env bash
#
# Incident Triage Script
# Production-grade triage workflow for Kubernetes incidents
# Captures evidence, assesses blast radius, classifies symptoms, recommends workflows
#
# Portable: Works on both macOS (BSD) and Linux (GNU)
#
# Usage: ./incident_triage.sh [options]
# Options:
#   --output-dir DIR       Directory for evidence capture (default: ./incident-<timestamp>)
#   --namespace NAMESPACE  Scope triage to specific namespace
#   --skip-dump           Skip full cluster-info dump (faster triage)
#   -h, --help            Show this help message

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_DIR=""
NAMESPACE=""
SKIP_DUMP=false
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Triage state
CONTROL_PLANE_STATUS="unknown"
BLAST_RADIUS="unknown"
declare -a SYMPTOMS=()
declare -a RECOMMENDATIONS=()

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
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

print_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

# Portable count function
count_lines() {
    local input
    input=$(cat)
    if [ -z "$input" ]; then
        echo 0
    else
        echo "$input" | wc -l | tr -d ' '
    fi
}

# Portable grep count
grep_count() {
    local result
    result=$(grep -c "$@" 2>/dev/null || true)
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

setup_output_dir() {
    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="./incident-${TIMESTAMP}"
    fi

    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        print_success "Created output directory: $OUTPUT_DIR"
    else
        print_info "Using existing directory: $OUTPUT_DIR"
    fi
}

capture_evidence() {
    print_header "PHASE 1: EVIDENCE CAPTURE"

    local evidence_dir="$OUTPUT_DIR/evidence"
    mkdir -p "$evidence_dir"

    # Capture cluster-info dump (optional, can be slow)
    if [ "$SKIP_DUMP" = false ]; then
        print_section "Capturing cluster-info dump (this may take a minute)"
        if kubectl cluster-info dump --all-namespaces --output-directory="$evidence_dir/cluster-info-dump" &> "$evidence_dir/cluster-info-dump.log"; then
            print_success "Cluster-info dump saved to $evidence_dir/cluster-info-dump"
        else
            print_warning "Cluster-info dump failed (non-critical, continuing)"
        fi
    else
        print_info "Skipping cluster-info dump (--skip-dump enabled)"
    fi

    # Capture nodes
    print_section "Capturing node status"
    kubectl get nodes -o wide > "$evidence_dir/nodes.txt" 2>&1
    kubectl get nodes -o json > "$evidence_dir/nodes.json" 2>&1
    print_success "Node status saved"

    # Capture pods
    print_section "Capturing pod status"
    local ns_flag
    if [ -n "$NAMESPACE" ]; then
        ns_flag="-n $NAMESPACE"
    else
        ns_flag="--all-namespaces"
    fi

    kubectl get pods $ns_flag -o wide > "$evidence_dir/pods.txt" 2>&1
    kubectl get pods $ns_flag -o json > "$evidence_dir/pods.json" 2>&1
    print_success "Pod status saved"

    # Capture warning events
    print_section "Capturing warning events"
    kubectl get events $ns_flag --field-selector type=Warning --sort-by='.lastTimestamp' > "$evidence_dir/warning-events.txt" 2>&1
    print_success "Warning events saved"

    # Capture all recent events
    kubectl get events $ns_flag --sort-by='.lastTimestamp' > "$evidence_dir/all-events.txt" 2>&1

    print_success "Evidence capture complete: $evidence_dir"
}

check_control_plane() {
    print_header "PHASE 2: CONTROL PLANE HEALTH"

    local readyz_output
    local readyz_verbose

    # Check /readyz
    if readyz_output=$(kubectl get --raw /readyz 2>&1); then
        print_success "Control plane is ready"
        CONTROL_PLANE_STATUS="healthy"
    else
        print_error "Control plane readiness check failed"
        CONTROL_PLANE_STATUS="degraded"
    fi

    # Check /readyz?verbose for detailed status
    print_section "Detailed readiness check"
    if readyz_verbose=$(kubectl get --raw '/readyz?verbose' 2>&1); then
        echo "$readyz_verbose" > "$OUTPUT_DIR/readyz-verbose.txt"

        # Parse the output to identify failing checks
        if echo "$readyz_verbose" | grep -q "\[-\]"; then
            print_warning "Some readiness checks are failing:"
            echo "$readyz_verbose" | grep "\[-\]" || true
            CONTROL_PLANE_STATUS="degraded"
            SYMPTOMS+=("control-plane-degraded")
        else
            print_success "All readiness checks passed"
        fi
    else
        print_warning "Could not retrieve verbose readiness status"
    fi

    # Check /healthz
    if kubectl get --raw /healthz &> /dev/null; then
        print_success "API server is healthy"
    else
        print_error "API server health check failed"
        CONTROL_PLANE_STATUS="unhealthy"
        SYMPTOMS+=("api-server-unhealthy")
    fi

    # Check control plane pods
    print_section "Control plane pod status"
    local control_plane_pods=$(kubectl get pods -n kube-system -l 'tier=control-plane' --no-headers 2>/dev/null || echo "")

    if [ -n "$control_plane_pods" ]; then
        local total=$(echo "$control_plane_pods" | count_lines)
        local running=$(echo "$control_plane_pods" | grep_count "Running")

        if [ "$running" -eq "$total" ]; then
            print_success "Control plane pods: $running/$total running"
        else
            print_error "Control plane pods: $running/$total running"
            CONTROL_PLANE_STATUS="degraded"
            SYMPTOMS+=("control-plane-pods-not-running")
        fi
    else
        print_info "Control plane pods not found (may be external)"
    fi
}

assess_blast_radius() {
    print_header "PHASE 3: BLAST RADIUS ASSESSMENT"

    local ns_flag
    if [ -n "$NAMESPACE" ]; then
        ns_flag="-n $NAMESPACE"
        print_info "Scoped to namespace: $NAMESPACE"
    else
        ns_flag="--all-namespaces"
    fi

    # Count total pods
    local total_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | count_lines)
    print_info "Total pods: $total_pods"

    # Count non-running pods
    local non_running_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | { grep -v "Running" || true; } | { grep -v "Completed" || true; } | count_lines)
    print_info "Non-running pods: $non_running_pods"

    # Count affected namespaces (pods not Running)
    local affected_namespaces=0
    if [ -z "$NAMESPACE" ]; then
        affected_namespaces=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | { grep -v "Running" || true; } | { grep -v "Completed" || true; } | awk '{print $1}' | sort -u | count_lines)
        print_info "Affected namespaces: $affected_namespaces"
    fi

    # Count affected nodes
    local notready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | { grep "NotReady" || true; } | count_lines)
    local pressure_nodes=$(kubectl get nodes -o json 2>/dev/null | { jq -r '.items[] | select(.status.conditions[] | select(.type=="DiskPressure" or .type=="MemoryPressure" or .type=="PIDPressure") | select(.status=="True")) | .metadata.name' || true; } 2>/dev/null | count_lines)
    local affected_nodes=$((notready_nodes + pressure_nodes))
    print_info "Affected nodes: $affected_nodes (NotReady: $notready_nodes, Pressure: $pressure_nodes)"

    # Classify blast radius
    print_section "Blast Radius Classification"

    if [ "$affected_nodes" -gt 0 ]; then
        BLAST_RADIUS="cluster-wide-infrastructure"
        print_critical "Cluster-wide infrastructure issue (node problems detected)"
        SYMPTOMS+=("node-failures")
    elif [ "$non_running_pods" -eq 0 ]; then
        BLAST_RADIUS="no-issues"
        print_success "No workload issues detected"
    elif [ "$non_running_pods" -eq 1 ] && [ -n "$NAMESPACE" ]; then
        BLAST_RADIUS="single-pod"
        print_info "Single pod issue"
    elif [ "$affected_namespaces" -eq 1 ] || [ -n "$NAMESPACE" ]; then
        BLAST_RADIUS="single-namespace"
        print_warning "Single namespace affected"
    elif [ "$affected_namespaces" -le 3 ]; then
        BLAST_RADIUS="multiple-namespaces"
        print_warning "Multiple namespaces affected ($affected_namespaces)"
    else
        BLAST_RADIUS="cluster-wide-workloads"
        print_critical "Cluster-wide workload issues"
    fi

    echo "$BLAST_RADIUS" > "$OUTPUT_DIR/blast-radius.txt"
}

classify_symptoms() {
    print_header "PHASE 4: SYMPTOM CLASSIFICATION"

    local ns_flag
    if [ -n "$NAMESPACE" ]; then
        ns_flag="-n $NAMESPACE"
    else
        ns_flag="--all-namespaces"
    fi

    # Detect Pending pods
    local pending_pods=$(kubectl get pods $ns_flag --field-selector=status.phase=Pending --no-headers 2>/dev/null | count_lines)
    if [ "$pending_pods" -gt 0 ]; then
        print_warning "Pending pods detected: $pending_pods"
        SYMPTOMS+=("pending-pods")
        kubectl get pods $ns_flag --field-selector=status.phase=Pending > "$OUTPUT_DIR/pending-pods.txt" 2>&1
    fi

    # Detect CrashLoopBackOff/Failed pods
    local crash_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|Error" | count_lines)
    if [ "$crash_pods" -gt 0 ]; then
        print_warning "Crashing pods detected: $crash_pods"
        SYMPTOMS+=("crashloop-pods")
        kubectl get pods $ns_flag --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|Error" > "$OUTPUT_DIR/crash-pods.txt" 2>&1
    fi

    # Detect OOMKilled
    local oom_pods=$(kubectl get pods $ns_flag -o json 2>/dev/null | jq -r '.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled") | .metadata.name' 2>/dev/null | count_lines)
    if [ "$oom_pods" -gt 0 ]; then
        print_warning "OOMKilled pods detected: $oom_pods"
        SYMPTOMS+=("oom-killed")
    fi

    # Detect ImagePullBackOff
    local image_pull_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | grep -E "ImagePullBackOff|ErrImagePull" | count_lines)
    if [ "$image_pull_pods" -gt 0 ]; then
        print_warning "Image pull issues detected: $image_pull_pods"
        SYMPTOMS+=("image-pull-errors")
    fi

    # Detect DNS/network events
    local dns_events=$(kubectl get events $ns_flag --no-headers 2>/dev/null | grep -iE "dns|network|timeout|connection refused" | count_lines)
    if [ "$dns_events" -gt 0 ]; then
        print_warning "DNS/network events detected: $dns_events"
        SYMPTOMS+=("network-dns-issues")
    fi

    # Detect storage/mount events
    local storage_events=$(kubectl get events $ns_flag --no-headers 2>/dev/null | grep -iE "FailedMount|FailedAttachVolume|FailedScheduling.*volume" | count_lines)
    if [ "$storage_events" -gt 0 ]; then
        print_warning "Storage/mount events detected: $storage_events"
        SYMPTOMS+=("storage-issues")
    fi

    # Detect scheduling failures
    local schedule_events=$(kubectl get events $ns_flag --no-headers 2>/dev/null | grep -iE "FailedScheduling" | count_lines)
    if [ "$schedule_events" -gt 0 ]; then
        print_warning "Scheduling failures detected: $schedule_events"
        SYMPTOMS+=("scheduling-failures")
    fi

    # Check for Helm releases (if helm is available)
    if command -v helm &> /dev/null; then
        local failed_releases=$(helm list $ns_flag --failed --no-headers 2>/dev/null | count_lines)
        if [ "$failed_releases" -gt 0 ]; then
            print_warning "Failed Helm releases detected: $failed_releases"
            SYMPTOMS+=("helm-failures")
        fi
    fi

    if [ ${#SYMPTOMS[@]} -eq 0 ]; then
        print_success "No critical symptoms detected"
    else
        print_section "Detected Symptoms"
        printf '%s\n' "${SYMPTOMS[@]}" | sort -u
    fi
}

generate_recommendations() {
    print_header "PHASE 5: RECOMMENDED WORKFLOWS"

    # Map symptoms to diagnostic workflows
    local -A workflow_map=(
        ["pending-pods"]="Pod diagnostics: Check scheduling constraints, resource availability, taints/tolerations"
        ["crashloop-pods"]="Pod diagnostics: Examine logs, exit codes, application errors"
        ["oom-killed"]="Pod diagnostics: Review memory limits, analyze resource usage patterns"
        ["image-pull-errors"]="Pod diagnostics: Verify image names, check imagePullSecrets, test registry access"
        ["network-dns-issues"]="Network debugging: Test DNS resolution, check CoreDNS, verify network policies"
        ["storage-issues"]="Storage diagnostics: Check PVC status, CSI driver health, volume attachments"
        ["scheduling-failures"]="Pod diagnostics + Node health: Check resource capacity, node conditions, pod requirements"
        ["node-failures"]="Node health: Examine node conditions, kubelet logs, resource pressure"
        ["control-plane-degraded"]="Cluster health: Check control plane pods, API server logs, etcd status"
        ["api-server-unhealthy"]="Cluster health: Urgent - API server investigation required"
        ["helm-failures"]="Helm debugging: Check release status, template validation, stuck releases"
    )

    local -A script_map=(
        ["pending-pods"]="pod_diagnostics.sh"
        ["crashloop-pods"]="pod_diagnostics.sh"
        ["oom-killed"]="pod_diagnostics.sh"
        ["image-pull-errors"]="pod_diagnostics.sh"
        ["network-dns-issues"]="network_debug.sh"
        ["storage-issues"]="storage_check.sh"
        ["scheduling-failures"]="pod_diagnostics.sh + cluster_health_check.sh"
        ["node-failures"]="cluster_health_check.sh"
        ["control-plane-degraded"]="cluster_health_check.sh"
        ["api-server-unhealthy"]="Manual investigation required"
        ["helm-failures"]="helm_release_debug.sh"
    )

    if [ ${#SYMPTOMS[@]} -eq 0 ]; then
        print_success "No specific issues detected. Cluster appears healthy."
        RECOMMENDATIONS+=("Run cluster_health_check.sh for detailed baseline assessment")
    else
        # Deduplicate and prioritize symptoms
        local -a unique_symptoms=($(printf '%s\n' "${SYMPTOMS[@]}" | sort -u))

        for symptom in "${unique_symptoms[@]}"; do
            if [ -n "${workflow_map[$symptom]:-}" ]; then
                print_section "$symptom"
                print_info "Workflow: ${workflow_map[$symptom]}"
                print_info "Script: ${script_map[$symptom]}"
                echo ""

                RECOMMENDATIONS+=("$symptom: ${script_map[$symptom]}")
            fi
        done
    fi
}

generate_triage_report() {
    print_header "GENERATING TRIAGE REPORT"

    local report_file="$OUTPUT_DIR/triage-report.md"
    local text_report="$OUTPUT_DIR/triage-summary.txt"

    # Create markdown report
    cat > "$report_file" <<EOF
# Kubernetes Incident Triage Report

**Generated**: $(date)
**Cluster**: $(kubectl config current-context)
**Scope**: ${NAMESPACE:-All namespaces}

## Executive Summary

- **Control Plane Status**: $CONTROL_PLANE_STATUS
- **Blast Radius**: $BLAST_RADIUS
- **Symptoms Detected**: ${#SYMPTOMS[@]}

## Blast Radius Assessment

\`\`\`
$BLAST_RADIUS
\`\`\`

EOF

    if [ ${#SYMPTOMS[@]} -gt 0 ]; then
        cat >> "$report_file" <<EOF
## Detected Symptoms

EOF
        printf -- '- %s\n' "${SYMPTOMS[@]}" | sort -u >> "$report_file"
    fi

    cat >> "$report_file" <<EOF

## Recommended Next Steps

EOF

    if [ ${#RECOMMENDATIONS[@]} -gt 0 ]; then
        printf -- '1. %s\n' "${RECOMMENDATIONS[@]}" >> "$report_file"
    else
        echo "No specific recommendations. Cluster appears healthy." >> "$report_file"
    fi

    cat >> "$report_file" <<EOF

## Evidence Location

All evidence has been captured in: \`$OUTPUT_DIR/evidence/\`

## Diagnostic Scripts

Run the following scripts from \`~/.claude/skills/k8s-troubleshooter/scripts/\`:

- **Pod issues**: \`pod_diagnostics.sh <POD_NAME> <NAMESPACE>\`
- **Network issues**: \`network_debug.sh <NAMESPACE>\`
- **Storage issues**: \`storage_check.sh <NAMESPACE>\`
- **Helm issues**: \`helm_release_debug.sh <RELEASE_NAME> <NAMESPACE>\`
- **Cluster health**: \`cluster_health_check.sh\`

## Reference Documentation

See \`~/.claude/skills/k8s-troubleshooter/reference/incident-response.md\` for detailed triage decision tree and investigation workflows.

---

Generated by k8s-troubleshooter incident_triage.sh
EOF

    # Create text summary
    cat > "$text_report" <<EOF
KUBERNETES INCIDENT TRIAGE SUMMARY
$(date)

Control Plane: $CONTROL_PLANE_STATUS
Blast Radius: $BLAST_RADIUS
Symptoms: ${#SYMPTOMS[@]}

Evidence captured in: $OUTPUT_DIR

Next steps:
EOF

    if [ ${#RECOMMENDATIONS[@]} -gt 0 ]; then
        printf '%s\n' "${RECOMMENDATIONS[@]}" >> "$text_report"
    else
        echo "No specific recommendations. Cluster appears healthy." >> "$text_report"
    fi

    print_success "Triage report saved: $report_file"
    print_success "Summary saved: $text_report"
}

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Production-grade incident triage workflow for Kubernetes clusters"
    echo ""
    echo "Options:"
    echo "  --output-dir DIR       Directory for evidence capture (default: ./incident-<timestamp>)"
    echo "  --namespace NAMESPACE  Scope triage to specific namespace"
    echo "  --skip-dump           Skip full cluster-info dump (faster triage)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --namespace production"
    echo "  $0 --output-dir /tmp/incident-20231201 --skip-dump"
    echo ""
    echo "The script will:"
    echo "  1. Capture evidence (nodes, pods, events, optional cluster-info dump)"
    echo "  2. Check control plane health (/readyz?verbose)"
    echo "  3. Assess blast radius (single pod -> cluster-wide)"
    echo "  4. Classify symptoms (crash loops, OOM, scheduling, networking, storage)"
    echo "  5. Recommend specific diagnostic workflows and scripts"
    echo ""
    echo "Output:"
    echo "  - Markdown triage report with executive summary"
    echo "  - Text summary for quick reference"
    echo "  - Evidence files for detailed investigation"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --skip-dump)
            SKIP_DUMP=true
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
    echo "========================================="
    echo "Kubernetes Incident Triage"
    echo "========================================="
    echo ""
    echo "Timestamp: $(date)"
    echo "Context: $(kubectl config current-context)"
    if [ -n "$NAMESPACE" ]; then
        echo "Scope: Namespace '$NAMESPACE'"
    else
        echo "Scope: All namespaces"
    fi
    echo ""

    check_prerequisites
    setup_output_dir
    capture_evidence
    check_control_plane
    assess_blast_radius
    classify_symptoms
    generate_recommendations
    generate_triage_report

    echo ""
    print_header "TRIAGE COMPLETE"
    echo ""
    echo "Summary:"
    cat "$OUTPUT_DIR/triage-summary.txt"
    echo ""
    echo "Full report: $OUTPUT_DIR/triage-report.md"
    echo "Evidence: $OUTPUT_DIR/evidence/"
}

main
