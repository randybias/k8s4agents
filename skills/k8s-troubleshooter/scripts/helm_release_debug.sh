#!/usr/bin/env bash
#
# Helm Release Debug Script
# Comprehensive Helm release status, history, and troubleshooting
#
# Usage: ./helm_release_debug.sh RELEASE_NAME NAMESPACE [options]
#

set -euo pipefail

# Default values
RELEASE_NAME=""
NAMESPACE="default"
CHART_PATH=""
VALUES_FILES=()
SET_ARGS=()
RUN_TESTS=false
RUN_DRY_RUN=false
RUN_DIFF=false
OUTPUT_FORMAT="text"
VALIDATE_CHART=false
LOG_TAIL_LINES=50

# Function to display help
show_help() {
    cat <<EOF
Helm Release Debug Script

Usage: $0 RELEASE_NAME NAMESPACE [options]

Arguments:
  RELEASE_NAME        Name of the Helm release to debug
  NAMESPACE           Kubernetes namespace (default: default)

Options:
  --chart PATH        Path to chart for validation and dry-run operations
  --values FILE       Values file(s) to use (can specify multiple times)
  --set KEY=VALUE     Set values on the command line (can specify multiple times)
  --set-string K=V    Set STRING values on the command line (can specify multiple times)
  --set-file K=PATH   Set values from files (can specify multiple times)
  --run-tests         Run helm test --logs after gathering diagnostics
  --run-dry-run       Perform client-side and server-side dry-run validations
  --diff              Show diff between current and proposed changes (requires helm-diff plugin)
  --validate-chart    Run helm lint and template validation on the chart
  --output FORMAT     Output format: text, json, yaml (default: text)
  --help, -h          Show this help message

Examples:
  # Basic debugging
  $0 myapp production

  # Debug with chart validation
  $0 myapp production --chart ./charts/myapp --validate-chart

  # Full diagnostic with tests and dry-run
  $0 myapp production --chart ./charts/myapp --values values.yaml --run-tests --run-dry-run

  # Show diff with custom values
  $0 myapp production --chart ./charts/myapp --values prod-values.yaml --diff

EOF
    exit 0
}

# Function to parse arguments
parse_arguments() {
    if [ $# -eq 0 ]; then
        show_help
    fi

    # First two positional arguments
    if [ $# -ge 1 ] && [[ ! "$1" =~ ^-- ]]; then
        RELEASE_NAME="$1"
        shift
    fi

    if [ $# -ge 1 ] && [[ ! "$1" =~ ^-- ]]; then
        NAMESPACE="$1"
        shift
    fi

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                show_help
                ;;
            --chart)
                CHART_PATH="$2"
                shift 2
                ;;
            --values)
                VALUES_FILES+=("$2")
                shift 2
                ;;
            --set)
                SET_ARGS+=("--set" "$2")
                shift 2
                ;;
            --set-string)
                SET_ARGS+=("--set-string" "$2")
                shift 2
                ;;
            --set-file)
                SET_ARGS+=("--set-file" "$2")
                shift 2
                ;;
            --run-tests)
                RUN_TESTS=true
                shift
                ;;
            --run-dry-run)
                RUN_DRY_RUN=true
                shift
                ;;
            --diff)
                RUN_DIFF=true
                shift
                ;;
            --validate-chart)
                VALIDATE_CHART=true
                shift
                ;;
            --output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$RELEASE_NAME" ]; then
        echo "Error: RELEASE_NAME is required"
        show_help
    fi
}

# Function to build helm command arguments
build_helm_args() {
    local args=()

    for values_file in "${VALUES_FILES[@]}"; do
        args+=("--values" "$values_file")
    done

    args+=("${SET_ARGS[@]}")

    echo "${args[@]}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print section header
print_section() {
    echo ""
    echo "============================================================"
    echo "=== $1"
    echo "============================================================"
}

# Function to get release status info
get_release_status() {
    print_section "Helm Release Status"

    local status_output
    if status_output=$(helm status "$RELEASE_NAME" -n "$NAMESPACE" --output "$OUTPUT_FORMAT" 2>&1); then
        echo "$status_output"

        # Extract and highlight critical status information
        if [ "$OUTPUT_FORMAT" = "text" ]; then
            echo ""
            echo "--- Status Summary ---"
            echo "$status_output" | grep -E "STATUS:|LAST DEPLOYED:|REVISION:" || true

            # Check for specific error states
            if echo "$status_output" | grep -q "STATUS: failed"; then
                echo ""
                echo "WARNING: Release is in FAILED state"
            elif echo "$status_output" | grep -q "STATUS: pending"; then
                echo ""
                echo "WARNING: Release is in PENDING state"
            elif echo "$status_output" | grep -q "STATUS: pending-install"; then
                echo ""
                echo "WARNING: Release is in PENDING-INSTALL state"
            elif echo "$status_output" | grep -q "STATUS: pending-upgrade"; then
                echo ""
                echo "WARNING: Release is in PENDING-UPGRADE state"
            fi
        fi
    else
        echo "ERROR: Failed to get release status"
        echo "$status_output"
        return 1
    fi
}

# Function to get release history
get_release_history() {
    print_section "Release History"

    if ! helm history "$RELEASE_NAME" -n "$NAMESPACE" 2>&1; then
        echo "ERROR: Failed to get release history"
    fi
}

# Function to get current release values
get_release_values() {
    print_section "Current Release Values"

    if ! helm get values "$RELEASE_NAME" -n "$NAMESPACE" --all 2>&1; then
        echo "ERROR: Failed to get release values"
    fi
}

# Function to get deployed manifest
get_deployed_manifest() {
    print_section "Deployed Manifest"

    local manifest
    if manifest=$(helm get manifest "$RELEASE_NAME" -n "$NAMESPACE" 2>&1); then
        if [ -z "$manifest" ] || [ "$manifest" = "---" ]; then
            echo "WARNING: Release has an empty manifest"
            echo "This may indicate a failed installation or upgrade"
        else
            echo "Manifest retrieved successfully (${#manifest} bytes)"
            echo ""
            echo "--- Manifest Preview (first 50 lines) ---"
            echo "$manifest" | head -50
        fi
    else
        echo "ERROR: Failed to get release manifest"
        echo "$manifest"
    fi
}

# Function to check deployed resources
check_deployed_resources() {
    print_section "Deployed Resources Status"

    local manifest
    if manifest=$(helm get manifest "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null); then
        if [ -z "$manifest" ] || [ "$manifest" = "---" ]; then
            echo "No resources to check (empty manifest)"
        else
            echo "$manifest" | kubectl get -f - -o wide 2>&1 || echo "Some resources may not exist or are not accessible"
        fi
    else
        echo "Could not retrieve manifest to check resources"
    fi
}

# Function to get helm hooks
get_helm_hooks() {
    print_section "Helm Hooks"

    local hooks
    if hooks=$(helm get hooks "$RELEASE_NAME" -n "$NAMESPACE" 2>&1); then
        if [ -z "$hooks" ] || [ "$hooks" = "---" ]; then
            echo "No hooks defined for this release"
        else
            echo "$hooks"
            echo ""
            echo "--- Hook Resources Analysis ---"

            # List hook-related jobs
            echo ""
            echo "Hook Jobs:"
            kubectl get jobs -n "$NAMESPACE" -l "app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=$RELEASE_NAME" 2>&1 || echo "No hook jobs found"

            # List hook-related pods
            echo ""
            echo "Hook Pods:"
            local hook_pods
            if hook_pods=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=$RELEASE_NAME" --field-selector=status.phase!=Running 2>/dev/null); then
                echo "$hook_pods"

                # Get details for failed/completed hook pods
                local pod_names
                pod_names=$(echo "$hook_pods" | awk 'NR>1 {print $1}')
                if [ -n "$pod_names" ]; then
                    echo ""
                    echo "--- Hook Pod Details ---"
                    for pod in $pod_names; do
                        echo ""
                        echo "Pod: $pod"
                        echo "Description:"
                        kubectl describe pod "$pod" -n "$NAMESPACE" 2>&1 | grep -A 20 "Events:" || true

                        echo ""
                        echo "Logs (last ${LOG_TAIL_LINES} lines):"
                        kubectl logs "$pod" -n "$NAMESPACE" --tail="${LOG_TAIL_LINES}" 2>&1 || echo "Could not retrieve logs"
                    done
                fi
            else
                echo "No hook pods found with issues"
            fi
        fi
    else
        echo "ERROR: Failed to get hooks"
        echo "$hooks"
    fi
}

# Function to get release notes
get_release_notes() {
    print_section "Release Notes"

    if ! helm get notes "$RELEASE_NAME" -n "$NAMESPACE" 2>&1; then
        echo "No release notes available"
    fi
}

# Function to check recent events
check_recent_events() {
    print_section "Recent Events"

    # Check if events are aged out
    local events_count
    events_count=$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | wc -l)

    if [ "$events_count" -le 1 ]; then
        echo "WARNING: No events found or events may have aged out"
        echo "Kubernetes events typically expire after 1 hour by default"
        echo "Consider checking logs or other persistent storage for historical data"
    else
        kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>&1 | tail -30 || echo "Could not retrieve events"

        echo ""
        echo "Note: Showing last 30 events. Events older than 1 hour may have been aged out."
    fi
}

# Function to check helm secrets
check_helm_secrets() {
    print_section "Helm Release Secrets"

    local secrets
    if secrets=$(kubectl get secrets -n "$NAMESPACE" -l "owner=helm,name=$RELEASE_NAME" -o wide 2>&1); then
        echo "$secrets"

        # Check for last error in secret
        echo ""
        echo "--- Last Error Analysis ---"
        local secret_names
        secret_names=$(echo "$secrets" | awk 'NR>1 {print $1}')

        if [ -n "$secret_names" ]; then
            for secret in $secret_names; do
                local release_data
                if release_data=$(kubectl get secret "$secret" -n "$NAMESPACE" -o jsonpath='{.data.release}' 2>/dev/null | base64 -d 2>/dev/null | base64 -d 2>/dev/null | gunzip 2>/dev/null); then
                    local last_error
                    if last_error=$(echo "$release_data" | grep -o '"last_test_suite_run":[^}]*' 2>/dev/null); then
                        echo "Secret: $secret"
                        echo "Last test suite info: $last_error"
                    fi

                    # Check for failed status
                    if echo "$release_data" | grep -q '"status":"failed"'; then
                        echo ""
                        echo "WARNING: Secret $secret indicates a FAILED release"
                        # Try to extract error info
                        local error_info
                        if error_info=$(echo "$release_data" | grep -o '"info":{[^}]*"description":"[^"]*"' 2>/dev/null); then
                            echo "Error info: $error_info"
                        fi
                    fi
                fi
            done
        else
            echo "No secrets to analyze"
        fi
    else
        echo "No Helm secrets found or could not access them"
        echo "$secrets"
    fi
}

# Function to check pods status
check_pods_status() {
    print_section "Pods Status"

    local pods
    if pods=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=$RELEASE_NAME" -o wide 2>&1); then
        echo "$pods"

        # Check for problematic pods
        echo ""
        echo "--- Problematic Pods Details ---"
        local failed_pods
        failed_pods=$(echo "$pods" | awk 'NR>1 && ($3 !~ /Running|Succeeded|Completed/) {print $1}')

        if [ -n "$failed_pods" ]; then
            for pod in $failed_pods; do
                echo ""
                echo "Pod: $pod"
                echo "Description:"
                kubectl describe pod "$pod" -n "$NAMESPACE" 2>&1 | tail -50 || true

                echo ""
                echo "Logs (last ${LOG_TAIL_LINES} lines):"
                kubectl logs "$pod" -n "$NAMESPACE" --tail="${LOG_TAIL_LINES}" 2>&1 || echo "Could not retrieve logs"
            done
        else
            echo "No problematic pods found"
        fi
    else
        echo "No pods found with standard Helm labels or could not access them"
        echo "$pods"
    fi
}

# Function to validate chart
validate_chart() {
    if [ "$VALIDATE_CHART" != true ] || [ -z "$CHART_PATH" ]; then
        return 0
    fi

    print_section "Chart Validation"

    echo "--- Helm Lint ---"
    local helm_args
    helm_args=$(build_helm_args)

    # shellcheck disable=SC2086
    if helm lint "$CHART_PATH" $helm_args 2>&1; then
        echo "Lint: PASSED"
    else
        echo "Lint: FAILED"
    fi

    echo ""
    echo "--- Template Validation ---"
    # shellcheck disable=SC2086
    if helm template "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" $helm_args --validate 2>&1 > /dev/null; then
        echo "Template validation: PASSED"
    else
        echo "Template validation: FAILED"
    fi
}

# Function to run dry-run
run_dry_run() {
    if [ "$RUN_DRY_RUN" != true ] || [ -z "$CHART_PATH" ]; then
        return 0
    fi

    print_section "Dry-Run Validation"

    local helm_args
    helm_args=$(build_helm_args)

    echo "--- Client-Side Dry-Run ---"
    # shellcheck disable=SC2086
    if helm upgrade "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" $helm_args --dry-run --debug 2>&1 | tail -100; then
        echo ""
        echo "Client-side dry-run: COMPLETED"
    else
        echo ""
        echo "Client-side dry-run: FAILED"
    fi

    echo ""
    echo "--- Server-Side Dry-Run ---"
    # shellcheck disable=SC2086
    if helm upgrade "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" $helm_args --dry-run --debug --dry-run-option=server 2>&1 | tail -100; then
        echo ""
        echo "Server-side dry-run: COMPLETED"
    else
        echo ""
        echo "Server-side dry-run: FAILED"
    fi
}

# Function to run diff
run_diff() {
    if [ "$RUN_DIFF" != true ] || [ -z "$CHART_PATH" ]; then
        return 0
    fi

    print_section "Release Diff"

    if ! command_exists helm-diff && ! helm plugin list | grep -q "diff"; then
        echo "WARNING: helm-diff plugin is not installed"
        echo "Install with: helm plugin install https://github.com/databus23/helm-diff"
        echo "Skipping diff operation"
        return 0
    fi

    local helm_args
    helm_args=$(build_helm_args)

    # shellcheck disable=SC2086
    if helm diff upgrade "$RELEASE_NAME" "$CHART_PATH" -n "$NAMESPACE" $helm_args 2>&1; then
        echo ""
        echo "Diff completed"
    else
        echo ""
        echo "Diff failed or no differences found"
    fi
}

# Function to run tests
run_tests() {
    if [ "$RUN_TESTS" != true ]; then
        return 0
    fi

    print_section "Helm Tests"

    echo "Running helm test --logs for release: $RELEASE_NAME"
    echo ""

    if helm test "$RELEASE_NAME" -n "$NAMESPACE" --logs 2>&1; then
        echo ""
        echo "Tests: PASSED"
    else
        echo ""
        echo "Tests: FAILED"

        echo ""
        echo "--- Test Failure Summary ---"
        # Get test pods
        local test_pods
        test_pods=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/managed-by=Helm,app.kubernetes.io/instance=$RELEASE_NAME,helm.sh/hook=test" 2>/dev/null || true)

        if [ -n "$test_pods" ]; then
            echo "$test_pods"

            local pod_names
            pod_names=$(echo "$test_pods" | awk 'NR>1 {print $1}')
            for pod in $pod_names; do
                echo ""
                echo "Failed Test Pod: $pod"
                kubectl logs "$pod" -n "$NAMESPACE" --tail="${LOG_TAIL_LINES}" 2>&1 || echo "Could not retrieve logs"
            done
        else
            echo "No test pods found"
        fi
    fi
}

# Function to generate summary
generate_summary() {
    print_section "Summary"

    # Get current status
    local status
    status=$(helm status "$RELEASE_NAME" -n "$NAMESPACE" --output json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

    echo "Release Name: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"
    echo "Current Status: $status"

    # Highlight issues
    case "$status" in
        failed)
            echo ""
            echo "CRITICAL: Release is in FAILED state"
            echo "Recommended actions:"
            echo "  1. Review the hooks and pod logs above"
            echo "  2. Check for resource constraints or configuration errors"
            echo "  3. Consider rolling back: helm rollback $RELEASE_NAME -n $NAMESPACE"
            ;;
        pending*|pending-install|pending-upgrade)
            echo ""
            echo "WARNING: Release is in PENDING state"
            echo "This usually indicates an ongoing or stuck operation"
            echo "Recommended actions:"
            echo "  1. Check for running hook jobs or pods"
            echo "  2. Review events for timeout or resource issues"
            echo "  3. If stuck, consider: helm rollback $RELEASE_NAME -n $NAMESPACE"
            ;;
        deployed)
            echo ""
            echo "Release is successfully deployed"
            ;;
    esac

    # Check for empty manifest
    local manifest
    manifest=$(helm get manifest "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "")
    if [ -z "$manifest" ] || [ "$manifest" = "---" ]; then
        echo ""
        echo "WARNING: Release has an empty manifest"
        echo "This may indicate a problem with the chart or installation"
    fi

    echo ""
    echo "Diagnostic report completed at: $(date)"
}

# Main execution
main() {
    parse_arguments "$@"

    echo "Helm Release Debug Report"
    echo "Generated: $(date)"
    echo "Release: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"

    # Core diagnostics (always run)
    get_release_status
    get_release_history
    get_release_values
    get_deployed_manifest
    check_deployed_resources
    get_helm_hooks
    get_release_notes
    check_recent_events
    check_helm_secrets
    check_pods_status

    # Optional validations
    validate_chart
    run_dry_run
    run_diff
    run_tests

    # Final summary
    generate_summary

    echo ""
    echo "============================================================"
    echo "Helm release debugging completed for: $RELEASE_NAME"
    echo "============================================================"
}

# Run main function
main "$@"
