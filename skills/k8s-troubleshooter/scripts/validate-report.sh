#!/usr/bin/env bash
#
# validate-report.sh - Validates k8s-troubleshooter report format compliance
# Used as a Stop hook to ensure reports follow the mandatory 7-section template
#
# Exit codes:
#   0 - Validation passed
#   1 - Critical validation failure (blocks session end)
#   2 - Warning (allows session end but logs issues)

set -euo pipefail

REPORT_FILE="${1:-output/report.md}"
ERRORS=0
WARNINGS=0

#######################################
# Check for required section header
# Arguments:
#   $1 - Section header to check (e.g., "## 0. Executive Triage Card")
# Returns:
#   0 if found, 1 if missing
#######################################
check_section() {
    local section="$1"
    if ! grep -qF "$section" "$REPORT_FILE"; then
        echo "ERROR: Missing required section: $section"
        return 1
    fi
    return 0
}

#######################################
# Check for FACT/INF labeling
# Returns:
#   0 if labels present, 2 if missing (warning only)
#######################################
check_fact_inf_labels() {
    local has_facts=0
    local has_infs=0

    if grep -q '\[FACT-[0-9]\+\]' "$REPORT_FILE"; then
        has_facts=1
    fi

    if grep -q '\[INF-[0-9]\+\]' "$REPORT_FILE"; then
        has_infs=1
    fi

    if [[ $has_facts -eq 0 ]]; then
        echo "WARNING: No [FACT-n] labels found in Assessment & Findings"
        return 2
    fi

    if [[ $has_infs -eq 0 ]]; then
        echo "WARNING: No [INF-n] labels found in Derived Inferences"
        return 2
    fi

    return 0
}

#######################################
# Check for key required elements
# Prints warnings and returns 1 if any warnings, 0 otherwise
#######################################
check_required_elements() {
    local found_warnings=0

    # Check for Most Dangerous Assumption
    if ! grep -q "Most Dangerous Assumption" "$REPORT_FILE"; then
        echo "WARNING: 'Most Dangerous Assumption' not found in Executive Card"
        found_warnings=1
    fi

    # Check for falsification tests
    if ! grep -q "Falsification Test" "$REPORT_FILE"; then
        echo "WARNING: No 'Falsification Test' found in Root Cause Analysis"
        found_warnings=1
    fi

    # Check for Proof of Work commands
    if ! grep -q "### Commands Executed" "$REPORT_FILE"; then
        echo "WARNING: 'Commands Executed' section missing from Proof of Work"
        found_warnings=1
    fi

    return $found_warnings
}

#######################################
# Main validation logic
#######################################
main() {
    echo "Validating incident triage report format..."
    echo "Report file: $REPORT_FILE"
    echo ""

    # Check if report file exists
    if [[ ! -f "$REPORT_FILE" ]]; then
        echo "ERROR: Report file not found at $REPORT_FILE"
        exit 1
    fi

    # Check for all 7 required sections
    echo "Checking for required sections..."

    check_section "## 0. Executive Triage Card" || ERRORS=$((ERRORS + 1))
    check_section "## 1. Problem Statement" || ERRORS=$((ERRORS + 1))
    check_section "## 2. Assessment & Findings" || ERRORS=$((ERRORS + 1))
    check_section "## 3. Root Cause Analysis" || ERRORS=$((ERRORS + 1))
    check_section "## 4. Remediation Plan" || ERRORS=$((ERRORS + 1))
    check_section "## 5. Proof of Work" || ERRORS=$((ERRORS + 1))
    check_section "## 6. Supporting Evidence" || ERRORS=$((ERRORS + 1))

    echo ""

    # Check for FACT/INF labels
    echo "Checking for FACT/INF labeling..."
    if ! check_fact_inf_labels; then
        WARNINGS=$((WARNINGS + 1))
    fi

    echo ""

    # Check for required elements
    echo "Checking for required elements..."
    if ! check_required_elements; then
        WARNINGS=$((WARNINGS + 1))
    fi

    echo ""
    echo "=========================================="

    # Report results
    if [[ $ERRORS -gt 0 ]]; then
        echo "VALIDATION FAILED: $ERRORS critical errors"
        echo ""
        echo "Your report does not follow the mandatory 7-section template."
        echo "Please read the template in k8s-troubleshooter/SKILL.md and regenerate."
        exit 1
    fi

    if [[ $WARNINGS -gt 0 ]]; then
        echo "VALIDATION PASSED with $WARNINGS warnings"
        echo ""
        echo "Report structure is correct but consider addressing warnings above."
        exit 2  # Exit code 2 = warning, allows session to end
    fi

    echo "VALIDATION PASSED - Report format compliant"
    exit 0
}

main "$@"
