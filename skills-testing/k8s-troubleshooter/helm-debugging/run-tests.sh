#!/usr/bin/env bash
# Main test runner for Helm debugging tests
#
# Supports running tests against:
# - Local kind cluster (default)
# - Remote Kubernetes cluster via KUBECONFIG
# - Remote cluster via SSH
#
# Usage:
#   ./run-tests.sh [options]
#
# Options:
#   --cluster-type TYPE       Cluster type: kind, remote, existing, auto (default: auto)
#   --kind-cluster NAME       Kind cluster name (default: helm-debug-test)
#   --remote-host HOST        Remote SSH host for cluster access
#   --remote-ssh-key PATH     SSH key for remote access
#   --remote-kubeconfig PATH  Path to remote kubeconfig file
#   --kubeconfig PATH         Local kubeconfig path (default: ~/.kube/config)
#   --category CATEGORY       Run tests from category: hooks, states, validation, dryrun, tests, other
#   --test TEST_ID            Run specific test by ID (e.g., HF-001)
#   --list                    List available tests
#   --verbose                 Enable verbose output
#   --no-cleanup              Skip cleanup after tests
#   --no-teardown             Don't teardown cluster after tests
#   --setup-only              Only setup cluster, don't run tests
#   --teardown-only           Only teardown cluster
#   --help                    Show this help message

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
# shellcheck source=lib/cluster.sh
source "$SCRIPT_DIR/lib/cluster.sh"
# shellcheck source=lib/test-framework.sh
source "$SCRIPT_DIR/lib/test-framework.sh"
# shellcheck source=lib/test-implementations.sh
source "$SCRIPT_DIR/lib/test-implementations.sh"

# Default options
CLUSTER_TYPE="${CLUSTER_TYPE:-auto}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-helm-debug-test}"
CATEGORY=""
TEST_ID=""
LIST_TESTS=false
NO_TEARDOWN=false
SETUP_ONLY=false
TEARDOWN_ONLY=false

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cluster-type)
                CLUSTER_TYPE="$2"
                shift 2
                ;;
            --kind-cluster)
                KIND_CLUSTER_NAME="$2"
                shift 2
                ;;
            --remote-host)
                REMOTE_SSH_HOST="$2"
                shift 2
                ;;
            --remote-ssh-key)
                REMOTE_SSH_KEY="$2"
                shift 2
                ;;
            --remote-kubeconfig)
                REMOTE_KUBECONFIG="$2"
                shift 2
                ;;
            --kubeconfig)
                KUBECONFIG_PATH="$2"
                export KUBECONFIG="$2"
                shift 2
                ;;
            --category)
                CATEGORY="$2"
                shift 2
                ;;
            --test)
                TEST_ID="$2"
                shift 2
                ;;
            --list)
                LIST_TESTS=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                shift
                ;;
            --no-teardown)
                NO_TEARDOWN=true
                shift
                ;;
            --setup-only)
                SETUP_ONLY=true
                shift
                ;;
            --teardown-only)
                TEARDOWN_ONLY=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    head -n 30 "$0" | grep "^#" | sed 's/^# \?//'
}

# List available tests
list_tests() {
    echo "Available Tests:"
    echo ""
    echo "Hook Failures (--category hooks):"
    echo "  HF-001: Pre-install hook failure"
    echo "  HF-002: Post-install hook failure"
    echo "  HF-003: Pre-upgrade hook failure"
    echo "  HF-004: Post-upgrade hook failure"
    echo "  HF-005: Stuck/hanging hook"
    echo "  HF-006: Hook timeout"
    echo "  HF-007: Hook delete policy issues"
    echo ""
    echo "Release State Issues (--category states):"
    echo "  RS-001: Failed release"
    echo "  RS-002: Pending-install state"
    echo "  RS-003: Pending-upgrade state"
    echo "  RS-004: Empty manifest"
    echo "  RS-005: Missing resources"
    echo ""
    echo "Chart Validation (--category validation):"
    echo "  CV-001: Invalid Chart.yaml"
    echo "  CV-002: YAML syntax errors"
    echo "  CV-003: Template rendering errors"
    echo "  CV-004: Missing required values"
    echo "  CV-005: Deprecated APIs"
    echo "  CV-006: YAML syntax errors"
    echo ""
    echo "Dry-Run Issues (--category dryrun):"
    echo "  DR-001: Client-side dry-run failures"
    echo "  DR-002: Server-side dry-run failures"
    echo "  DR-003: API compatibility issues"
    echo "  DR-004: Resource quota violations"
    echo "  DR-005: RBAC permission issues"
    echo ""
    echo "Test Failures (--category tests):"
    echo "  TF-001: Helm test failures"
    echo "  TF-002: Test pod timeout"
    echo "  TF-003: Test pod ImagePullBackOff"
    echo "  TF-004: Service not ready during tests"
    echo ""
    echo "Other Scenarios (--category other):"
    echo "  OS-001: Resource name conflicts"
    echo "  OS-002: Database migration failures"
    echo "  OS-003: Configuration errors"
    echo ""
    echo "Note: Only tests with implementations (HF-001, HF-002, RS-001, CV-001, TF-001) are currently automated."
}

# Get tests to run based on category or specific test
get_tests_to_run() {
    if [ -n "$TEST_ID" ]; then
        # Specific test requested
        echo "$TEST_ID"
        return
    fi

    case "$CATEGORY" in
        hooks)
            echo "HF-001 HF-002"
            ;;
        states)
            echo "RS-001"
            ;;
        validation)
            echo "CV-001"
            ;;
        tests)
            echo "TF-001"
            ;;
        "")
            # Run all implemented tests
            echo "HF-001 HF-002 RS-001 CV-001 TF-001"
            ;;
        *)
            echo "ERROR: Unknown category: $CATEGORY" >&2
            echo "Available categories: hooks, states, validation, dryrun, tests, other" >&2
            exit 1
            ;;
    esac
}

# Run a single test
run_test() {
    local test_id="$1"

    # Convert test ID to function name (HF-001 -> test_hf_001)
    local func_name
    func_name="test_$(echo "$test_id" | tr '[:upper:]' '[:lower:]' | tr '-' '_')"

    # Check if function exists
    if ! declare -f "$func_name" >/dev/null 2>&1; then
        log_warning "Test $test_id not yet implemented (function $func_name not found)"
        return 0
    fi

    # Run the test
    if "$func_name"; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"

    # Handle list command
    if [ "$LIST_TESTS" = "true" ]; then
        list_tests
        exit 0
    fi

    # Create output directory
    mkdir -p "$TEST_OUTPUT_DIR"
    log_info "Test output directory: $TEST_OUTPUT_DIR"

    # Handle teardown-only
    if [ "$TEARDOWN_ONLY" = "true" ]; then
        log_info "Tearing down cluster..."
        teardown_cluster
        exit 0
    fi

    # Setup cluster
    log_info "Setting up test environment..."
    if ! setup_cluster; then
        log_error "Failed to setup cluster"
        exit 1
    fi

    # Verify cluster is ready
    if ! verify_cluster_ready; then
        log_error "Cluster is not ready"
        exit 1
    fi

    # Handle setup-only
    if [ "$SETUP_ONLY" = "true" ]; then
        log_success "Cluster setup complete"
        exit 0
    fi

    # Get tests to run
    local tests_to_run
    tests_to_run=$(get_tests_to_run)

    log_info "Running tests: $tests_to_run"
    echo ""

    # Run tests
    for test_id in $tests_to_run; do
        run_test "$test_id" || true
    done

    # Print summary
    echo ""
    print_test_summary
    local exit_code=$?

    # Teardown cluster if requested
    if [ "$NO_TEARDOWN" != "true" ]; then
        echo ""
        log_info "Tearing down test environment..."
        teardown_cluster
    else
        log_warning "Cluster left running (--no-teardown specified)"
    fi

    exit $exit_code
}

# Run main
main "$@"
