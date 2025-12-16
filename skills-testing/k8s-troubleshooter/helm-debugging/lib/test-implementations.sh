#!/usr/bin/env bash
# Test implementations for Helm debugging tests

set -euo pipefail

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/test-framework.sh
source "$SCRIPT_DIR/test-framework.sh"

# Hook Failure Tests

test_hf_001() {
    test_begin "HF-001" "Pre-Install Hook Failure"

    local namespace="helm-test-hooks"
    local release="test-pre-install-fail"
    local chart="$TEST_CHARTS_DIR/hook-pre-install-fail"
    local checks_passed=0

    # Deploy chart with failing pre-install hook
    log_info "Installing chart with failing pre-install hook..."
    helm install "$release" "$chart" -n "$namespace" --wait=false 2>&1 | \
        tee "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/install.log" || true

    # Wait a bit for hook to fail
    sleep 10

    # Check 1: Release should be in failed/pending state
    if helm list -n "$namespace" --all | grep -E "$release.*(failed|pending)"; then
        ((checks_passed++))
        log_verbose "✓ Release in failed/pending state"
    else
        log_error "✗ Release not in expected state"
    fi

    # Check 2: Hook job should exist and be failed
    if assert_job_status "$namespace" "helm.sh/hook=pre-install" "failed"; then
        ((checks_passed++))
    fi

    # Check 3: Run debug script
    log_info "Running helm_release_debug.sh..."
    "$HELM_DEBUG_SCRIPT" "$release" "$namespace" > "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" 2>&1 || true

    # Check 4: Debug script should identify hook failure
    if assert_output_contains "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" "hook" "hook mention"; then
        ((checks_passed++))
    fi

    # Cleanup
    cleanup_helm_release "$release" "$namespace"
    kubectl delete jobs -n "$namespace" -l "helm.sh/hook=pre-install" --force --grace-period=0 2>/dev/null || true

    # Pass if at least 3 checks passed
    if [ $checks_passed -ge 3 ]; then
        test_end "pass" "Detected pre-install hook failure ($checks_passed/4 checks)"
        return 0
    else
        test_end "fail" "Only $checks_passed/4 checks passed"
        return 1
    fi
}

test_hf_002() {
    test_begin "HF-002" "Post-Install Hook Failure"

    local namespace="helm-test-hooks"
    local release="test-post-install-fail"
    local chart="$TEST_CHARTS_DIR/hook-post-install-fail"
    local checks_passed=0

    # Deploy chart with failing post-install hook
    log_info "Installing chart with failing post-install hook..."
    helm install "$release" "$chart" -n "$namespace" --wait=false 2>&1 | \
        tee "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/install.log" || true

    # Wait for deployment and hook
    sleep 15

    # Check 1: Main app should be running
    if kubectl get pods -n "$namespace" -l "app=test-app" | grep -q "Running"; then
        ((checks_passed++))
        log_verbose "✓ Main app is running"
    else
        log_error "✗ Main app not running"
    fi

    # Check 2: Post-hook should be failed
    if assert_job_status "$namespace" "helm.sh/hook=post-install" "failed"; then
        ((checks_passed++))
    fi

    # Check 3: Run debug script
    log_info "Running helm_release_debug.sh..."
    "$HELM_DEBUG_SCRIPT" "$release" "$namespace" > "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" 2>&1 || true

    # Check 4: Debug script output should mention hooks
    if assert_output_contains "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" "post.*install\|hook" "post-install hook"; then
        ((checks_passed++))
    fi

    # Cleanup
    cleanup_helm_release "$release" "$namespace"
    cleanup_namespace_resources "$namespace"

    if [ $checks_passed -ge 3 ]; then
        test_end "pass" "Detected post-install hook failure ($checks_passed/4 checks)"
        return 0
    else
        test_end "fail" "Only $checks_passed/4 checks passed"
        return 1
    fi
}

# Release State Tests

test_rs_001() {
    test_begin "RS-001" "Failed Release"

    local namespace="helm-test-states"
    local release="test-failed"
    local chart="$TEST_CHARTS_DIR/failed-release"
    local checks_passed=0

    # Deploy chart that will fail (invalid image)
    log_info "Installing chart with invalid image..."
    helm install "$release" "$chart" -n "$namespace" --wait=false 2>&1 | \
        tee "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/install.log" || true

    # Wait for failure to manifest
    sleep 20

    # Check 1: Pod should show ImagePullBackOff
    if kubectl get pods -n "$namespace" -l "app=test-app" -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' | \
        grep -qE "ImagePullBackOff|ErrImagePull"; then
        ((checks_passed++))
        log_verbose "✓ Pod shows ImagePullBackOff"
    else
        log_error "✗ Pod not in expected state"
    fi

    # Check 2: Events should show image pull errors
    if kubectl get events -n "$namespace" --sort-by='.lastTimestamp' | grep -iq "image\|pull\|error"; then
        ((checks_passed++))
        log_verbose "✓ Events show image errors"
    fi

    # Check 3: Run debug script
    log_info "Running helm_release_debug.sh..."
    "$HELM_DEBUG_SCRIPT" "$release" "$namespace" > "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" 2>&1 || true

    # Check 4: Debug script should identify the issue
    if assert_output_contains "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" "image\|pull\|back.*off" "image pull issue"; then
        ((checks_passed++))
    fi

    # Cleanup
    cleanup_helm_release "$release" "$namespace"
    cleanup_namespace_resources "$namespace"

    if [ $checks_passed -ge 3 ]; then
        test_end "pass" "Detected failed release ($checks_passed/4 checks)"
        return 0
    else
        test_end "fail" "Only $checks_passed/4 checks passed"
        return 1
    fi
}

# Chart Validation Tests

test_cv_001() {
    test_begin "CV-001" "Lint Failures - Invalid Chart.yaml"

    local chart="$TEST_CHARTS_DIR/lint-fail-chart-yaml"
    local checks_passed=0

    # Check 1: Helm lint should fail
    log_info "Running helm lint..."
    if assert_command_fails "helm lint should fail" helm lint "$chart"; then
        ((checks_passed++))
    fi

    # Check 2: Lint output should mention version or Chart.yaml
    helm lint "$chart" 2>&1 | tee "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/lint.log" || true
    if assert_output_contains "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/lint.log" "version\|Chart\.yaml" "Chart.yaml issue"; then
        ((checks_passed++))
    fi

    # Check 3: helm install dry-run should also fail
    log_info "Testing dry-run..."
    if assert_command_fails "dry-run should fail" helm install test "$chart" --dry-run; then
        ((checks_passed++))
    fi

    if [ $checks_passed -ge 2 ]; then
        test_end "pass" "Detected Chart.yaml validation failure ($checks_passed/3 checks)"
        return 0
    else
        test_end "fail" "Only $checks_passed/3 checks passed"
        return 1
    fi
}

# Test Failure Tests

test_tf_001() {
    test_begin "TF-001" "Helm Test Failures"

    local namespace="helm-test-tests"
    local release="test-fail-test"
    local chart="$TEST_CHARTS_DIR/test-failure"
    local checks_passed=0

    # Deploy chart
    log_info "Installing chart..."
    helm install "$release" "$chart" -n "$namespace" 2>&1 | \
        tee "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/install.log"

    # Wait for deployment
    if wait_for_condition "pods ready" 60 "kubectl get pods -n $namespace -l app=test-app -o jsonpath='{.items[0].status.phase}' | grep -q Running"; then
        ((checks_passed++))
        log_verbose "✓ App deployed successfully"
    else
        log_error "✗ App failed to deploy"
    fi

    # Run helm test (should fail)
    log_info "Running helm test..."
    helm test "$release" -n "$namespace" --logs 2>&1 | \
        tee "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/test.log" || true

    # Check 2: Test should fail
    if ! helm test "$release" -n "$namespace" >/dev/null 2>&1; then
        ((checks_passed++))
        log_verbose "✓ Helm test failed as expected"
    else
        log_error "✗ Helm test succeeded (expected failure)"
    fi

    # Check 3: Run debug script with --run-tests
    log_info "Running helm_release_debug.sh with --run-tests..."
    "$HELM_DEBUG_SCRIPT" "$release" "$namespace" --run-tests > "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" 2>&1 || true

    # Check 4: Debug script should identify test failure
    if assert_output_contains "$TEST_OUTPUT_DIR/$CURRENT_TEST_ID/debug.log" "test" "test mention"; then
        ((checks_passed++))
    fi

    # Cleanup
    kubectl delete pods -n "$namespace" -l "helm.sh/hook=test" --force --grace-period=0 2>/dev/null || true
    cleanup_helm_release "$release" "$namespace"

    if [ $checks_passed -ge 3 ]; then
        test_end "pass" "Detected helm test failure ($checks_passed/4 checks)"
        return 0
    else
        test_end "fail" "Only $checks_passed/4 checks passed"
        return 1
    fi
}

# Export test functions
export -f test_hf_001 test_hf_002
export -f test_rs_001
export -f test_cv_001
export -f test_tf_001
