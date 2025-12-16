#!/usr/bin/env bash
# Test execution framework for Helm debugging tests

set -euo pipefail

# Test execution and assertion framework

# Global test state
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST_ID=""
CURRENT_TEST_NAME=""
TEST_START_TIME=""
TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR:-/tmp/helm-debug-tests}"
VERBOSE="${VERBOSE:-false}"
NO_CLEANUP="${NO_CLEANUP:-false}"

# Test charts directory
TEST_CHARTS_DIR="${TEST_CHARTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../test-charts" && pwd)}"

# Debug script path
HELM_DEBUG_SCRIPT="${HELM_DEBUG_SCRIPT:-/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh}"

# Colors for output
if [ -t 1 ]; then
    COLOR_RESET="\033[0m"
    COLOR_RED="\033[31m"
    COLOR_GREEN="\033[32m"
    COLOR_YELLOW="\033[33m"
    COLOR_BLUE="\033[34m"
    COLOR_BOLD="\033[1m"
else
    COLOR_RESET=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_BOLD=""
fi

# Logging functions
log() {
    echo -e "${COLOR_RESET}$*${COLOR_RESET}"
}

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[PASS]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} $*"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

log_skip() {
    echo -e "${COLOR_YELLOW}[SKIP]${COLOR_RESET} $*"
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${COLOR_RESET}  $*${COLOR_RESET}"
    fi
}

# Test lifecycle functions
test_begin() {
    local test_id="$1"
    local test_name="$2"

    CURRENT_TEST_ID="$test_id"
    CURRENT_TEST_NAME="$test_name"
    TEST_START_TIME=$(date +%s)
    ((TESTS_RUN++))

    # Create output directory for this test
    mkdir -p "$TEST_OUTPUT_DIR/$test_id"

    echo ""
    echo "========================================"
    echo "Test: $test_id - $test_name"
    echo "========================================"
}

test_end() {
    local status="$1"
    local message="${2:-}"

    local duration=$(($(date +%s) - TEST_START_TIME))

    case "$status" in
        pass)
            ((TESTS_PASSED++))
            log_success "Test $CURRENT_TEST_ID passed in ${duration}s"
            if [ -n "$message" ]; then
                log "  $message"
            fi
            ;;
        fail)
            ((TESTS_FAILED++))
            log_error "Test $CURRENT_TEST_ID failed in ${duration}s"
            if [ -n "$message" ]; then
                log_error "  $message"
            fi
            ;;
        skip)
            ((TESTS_SKIPPED++))
            log_skip "Test $CURRENT_TEST_ID skipped"
            if [ -n "$message" ]; then
                log "  $message"
            fi
            ;;
    esac

    # Cleanup unless NO_CLEANUP is set
    if [ "$NO_CLEANUP" != "true" ]; then
        log_verbose "Running cleanup for test $CURRENT_TEST_ID"
    fi
}

# Assertion functions
assert_command_succeeds() {
    local description="$1"
    shift
    local output_file="$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/$(date +%s%N).log"

    log_verbose "Checking: $description"

    if "$@" > "$output_file" 2>&1; then
        log_verbose "  ✓ Command succeeded"
        return 0
    else
        log_error "  ✗ Command failed: $description"
        if [ "$VERBOSE" = "true" ]; then
            log_error "Command output:"
            cat "$output_file" | head -20
        fi
        return 1
    fi
}

assert_command_fails() {
    local description="$1"
    shift
    local output_file="$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/$(date +%s%N).log"

    log_verbose "Checking: $description"

    if "$@" > "$output_file" 2>&1; then
        log_error "  ✗ Command succeeded (expected failure): $description"
        return 1
    else
        log_verbose "  ✓ Command failed as expected"
        return 0
    fi
}

assert_helm_release_status() {
    local release="$1"
    local namespace="$2"
    local expected_status="$3"

    log_verbose "Checking Helm release status: $release in $namespace"

    local actual_status
    actual_status=$(helm list -n "$namespace" --all -o json | \
        jq -r ".[] | select(.name == \"$release\") | .status" 2>/dev/null || echo "not-found")

    if [ "$actual_status" = "$expected_status" ]; then
        log_verbose "  ✓ Release status is '$expected_status'"
        return 0
    else
        log_error "  ✗ Expected status '$expected_status', got '$actual_status'"
        return 1
    fi
}

assert_helm_release_exists() {
    local release="$1"
    local namespace="$2"

    log_verbose "Checking if Helm release exists: $release in $namespace"

    if helm list -n "$namespace" --all | grep -q "^$release"; then
        log_verbose "  ✓ Release exists"
        return 0
    else
        log_error "  ✗ Release does not exist"
        return 1
    fi
}

assert_pod_status() {
    local namespace="$1"
    local label_selector="$2"
    local expected_status="$3"

    log_verbose "Checking pod status in $namespace with labels $label_selector"

    local pods
    pods=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")

    if [ -z "$pods" ]; then
        log_error "  ✗ No pods found"
        return 1
    fi

    if echo "$pods" | grep -q "$expected_status"; then
        log_verbose "  ✓ Found pod with status '$expected_status'"
        return 0
    else
        log_error "  ✗ Expected pod status '$expected_status', got: $pods"
        return 1
    fi
}

assert_job_status() {
    local namespace="$1"
    local label_selector="$2"
    local expected_status="$3"

    log_verbose "Checking job status in $namespace with labels $label_selector"

    local jobs
    jobs=$(kubectl get jobs -n "$namespace" -l "$label_selector" -o json 2>/dev/null || echo '{"items":[]}')

    if [ "$(echo "$jobs" | jq '.items | length')" -eq 0 ]; then
        log_error "  ✗ No jobs found"
        return 1
    fi

    case "$expected_status" in
        succeeded)
            local succeeded
            succeeded=$(echo "$jobs" | jq '[.items[].status.succeeded // 0] | add')
            if [ "$succeeded" -gt 0 ]; then
                log_verbose "  ✓ Job succeeded"
                return 0
            fi
            ;;
        failed)
            local failed
            failed=$(echo "$jobs" | jq '[.items[].status.failed // 0] | add')
            if [ "$failed" -gt 0 ]; then
                log_verbose "  ✓ Job failed"
                return 0
            fi
            ;;
        active)
            local active
            active=$(echo "$jobs" | jq '[.items[].status.active // 0] | add')
            if [ "$active" -gt 0 ]; then
                log_verbose "  ✓ Job is active"
                return 0
            fi
            ;;
    esac

    log_error "  ✗ Job status does not match expected '$expected_status'"
    return 1
}

assert_output_contains() {
    local output_file="$1"
    local pattern="$2"
    local description="${3:-pattern}"

    log_verbose "Checking output contains: $description"

    if grep -iq "$pattern" "$output_file"; then
        log_verbose "  ✓ Output contains '$description'"
        return 0
    else
        log_error "  ✗ Output does not contain '$description'"
        if [ "$VERBOSE" = "true" ]; then
            log_error "Output content:"
            cat "$output_file" | head -20
        fi
        return 1
    fi
}

assert_output_not_contains() {
    local output_file="$1"
    local pattern="$2"
    local description="${3:-pattern}"

    log_verbose "Checking output does not contain: $description"

    if grep -iq "$pattern" "$output_file"; then
        log_error "  ✗ Output contains '$description' (should not)"
        return 1
    else
        log_verbose "  ✓ Output does not contain '$description'"
        return 0
    fi
}

# Cleanup helpers
cleanup_helm_release() {
    local release="$1"
    local namespace="$2"

    log_verbose "Cleaning up Helm release: $release in $namespace"

    if helm list -n "$namespace" --all | grep -q "^$release"; then
        helm uninstall "$release" -n "$namespace" 2>/dev/null || true
        log_verbose "  Uninstalled release: $release"
    fi
}

cleanup_namespace_resources() {
    local namespace="$1"

    log_verbose "Cleaning up all resources in namespace: $namespace"

    # Delete all helm releases
    helm list -n "$namespace" --all --short 2>/dev/null | while read -r release; do
        [ -n "$release" ] && helm uninstall "$release" -n "$namespace" 2>/dev/null || true
    done

    # Force delete jobs
    kubectl delete jobs -n "$namespace" --all --force --grace-period=0 2>/dev/null || true

    # Delete pods
    kubectl delete pods -n "$namespace" --all --force --grace-period=0 2>/dev/null || true

    log_verbose "  Cleaned up namespace: $namespace"
}

# Wait helpers
wait_for_condition() {
    local description="$1"
    local timeout="$2"
    local check_command="$3"

    log_verbose "Waiting for: $description (timeout: ${timeout}s)"

    local elapsed=0
    while [ $elapsed -lt "$timeout" ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            log_verbose "  ✓ Condition met after ${elapsed}s"
            return 0
        fi
        sleep 2
        ((elapsed+=2))
    done

    log_error "  ✗ Timeout waiting for: $description"
    return 1
}

# Test summary
print_test_summary() {
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Total tests:   $TESTS_RUN"
    echo -e "Passed:        ${COLOR_GREEN}$TESTS_PASSED${COLOR_RESET}"
    echo -e "Failed:        ${COLOR_RED}$TESTS_FAILED${COLOR_RESET}"
    echo -e "Skipped:       ${COLOR_YELLOW}$TESTS_SKIPPED${COLOR_RESET}"
    echo "========================================"

    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${COLOR_RED}Some tests failed${COLOR_RESET}"
        return 1
    else
        echo -e "${COLOR_GREEN}All tests passed${COLOR_RESET}"
        return 0
    fi
}

# Export functions
export -f log log_info log_success log_error log_warning log_skip log_verbose
export -f test_begin test_end
export -f assert_command_succeeds assert_command_fails
export -f assert_helm_release_status assert_helm_release_exists
export -f assert_pod_status assert_job_status
export -f assert_output_contains assert_output_not_contains
export -f cleanup_helm_release cleanup_namespace_resources
export -f wait_for_condition
export -f print_test_summary
