# Helm Debugging Test Suite

Comprehensive testing framework for validating the `helm_release_debug.sh` script and Helm debugging procedures. Tests cover 30 failure scenarios including hook failures, release state issues, chart validation problems, dry-run failures, test failures, and configuration errors.

## Overview

This test suite:
- **30 test scenarios** covering all major Helm failure modes
- **Automated test execution** with detailed assertions
- **Multiple cluster support**: local kind clusters, remote Kubernetes, or existing contexts
- **Comprehensive reporting** with pass/fail status and diagnostics

## Quick Start

### Run All Tests (Local Kind Cluster)

```bash
# Automatically creates a kind cluster, runs tests, and tears down
cd /Users/rbias/code/k8s4agents/skills-testing/k8s-troubleshooter/helm-debugging
./run-tests.sh
```

### Run Against Remote Cluster

```bash
# Using existing KUBECONFIG
./run-tests.sh --cluster-type remote --kubeconfig /path/to/kubeconfig

# Or via SSH
./run-tests.sh --cluster-type remote \
  --remote-host user@remote-host.example.com \
  --remote-ssh-key ~/.ssh/id_rsa
```

### Run Specific Test Category

```bash
# Run only hook failure tests
./run-tests.sh --category hooks

# Run only validation tests
./run-tests.sh --category validation
```

### Run Single Test

```bash
# Run specific test by ID
./run-tests.sh --test HF-001
```

## Directory Structure

```
helm-debugging/
├── README.md                  # This file
├── test-plan.md               # Comprehensive test plan with all 30 scenarios
├── run-tests.sh               # Main test runner
├── lib/                       # Test framework libraries
│   ├── cluster.sh             # Cluster management (kind/remote)
│   ├── test-framework.sh      # Test execution framework
│   └── test-implementations.sh # Test implementations
└── test-charts/               # 30 test charts with intentional failures
    ├── hook-pre-install-fail/
    ├── hook-post-install-fail/
    ├── failed-release/
    └── ... (27 more charts)
```

## Test Categories

### Hook Failures (7 tests)
- **HF-001**: Pre-install hook failure
- **HF-002**: Post-install hook failure
- **HF-003**: Pre-upgrade hook failure
- **HF-004**: Post-upgrade hook failure
- **HF-005**: Stuck/hanging hook
- **HF-006**: Hook timeout
- **HF-007**: Hook delete policy issues

### Release State Issues (5 tests)
- **RS-001**: Failed release (ImagePullBackOff)
- **RS-002**: Pending-install state
- **RS-003**: Pending-upgrade state
- **RS-004**: Empty manifest
- **RS-005**: Missing resources (deleted outside Helm)

### Chart Validation (6 tests)
- **CV-001**: Invalid Chart.yaml
- **CV-002**: YAML syntax errors
- **CV-003**: Template rendering errors
- **CV-004**: Missing required values
- **CV-005**: Deprecated Kubernetes APIs
- **CV-006**: YAML syntax errors

### Dry-Run Issues (5 tests)
- **DR-001**: Client-side dry-run failures
- **DR-002**: Server-side dry-run failures
- **DR-003**: API compatibility issues
- **DR-004**: Resource quota violations
- **DR-005**: RBAC permission issues

### Test Failures (4 tests)
- **TF-001**: Helm test failures
- **TF-002**: Test pod timeout
- **TF-003**: Test pod ImagePullBackOff
- **TF-004**: Service not ready during tests

### Other Scenarios (3 tests)
- **OS-001**: Resource name conflicts
- **OS-002**: Database migration failures
- **OS-003**: Configuration errors

**Note**: Currently 5 tests (HF-001, HF-002, RS-001, CV-001, TF-001) have automated implementations. Additional implementations can be added to `lib/test-implementations.sh`.

## Usage Examples

### Local Development with Kind

```bash
# Run all tests with verbose output
./run-tests.sh --verbose

# Leave cluster running for debugging
./run-tests.sh --no-teardown --no-cleanup

# Setup cluster only (for manual testing)
./run-tests.sh --setup-only

# Cleanup when done
./run-tests.sh --teardown-only
```

### CI/CD Pipeline

```bash
# Run tests in CI with specific kind cluster name
export KIND_CLUSTER_NAME=ci-helm-test-$BUILD_ID
./run-tests.sh --verbose

# Exit code: 0 if all tests pass, 1 if any fail
```

### Remote Kubernetes Cluster

```bash
# Use existing kubeconfig
export KUBECONFIG=/path/to/remote-kubeconfig
./run-tests.sh --cluster-type existing --no-teardown

# Fetch kubeconfig via SSH
./run-tests.sh --cluster-type remote \
  --remote-host admin@k8s-master.example.com \
  --remote-ssh-key ~/.ssh/k8s-key \
  --no-teardown
```

### Testing Specific Scenarios

```bash
# Test all hook failures
./run-tests.sh --category hooks --verbose

# Test single scenario with no cleanup for debugging
./run-tests.sh --test HF-001 --no-cleanup --no-teardown

# List all available tests
./run-tests.sh --list
```

## Command-Line Options

```
Options:
  --cluster-type TYPE       Cluster type: kind, remote, existing, auto (default: auto)
  --kind-cluster NAME       Kind cluster name (default: helm-debug-test)
  --remote-host HOST        Remote SSH host for cluster access
  --remote-ssh-key PATH     SSH key for remote access
  --remote-kubeconfig PATH  Path to remote kubeconfig file
  --kubeconfig PATH         Local kubeconfig path (default: ~/.kube/config)
  --category CATEGORY       Run tests from category: hooks, states, validation, dryrun, tests, other
  --test TEST_ID            Run specific test by ID (e.g., HF-001)
  --list                    List available tests
  --verbose                 Enable verbose output
  --no-cleanup              Skip cleanup after tests
  --no-teardown             Don't teardown cluster after tests
  --setup-only              Only setup cluster, don't run tests
  --teardown-only           Only teardown cluster
  --help                    Show help message
```

## Environment Variables

```bash
# Cluster configuration
export CLUSTER_TYPE=kind|remote|existing|auto
export KIND_CLUSTER_NAME=helm-debug-test
export KUBECONFIG=/path/to/kubeconfig
export REMOTE_SSH_HOST=user@host
export REMOTE_SSH_KEY=/path/to/key
export REMOTE_KUBECONFIG=/path/to/remote/kubeconfig

# Test configuration
export VERBOSE=true|false
export NO_CLEANUP=true|false
export TEST_OUTPUT_DIR=/path/to/output
export TEST_CHARTS_DIR=/path/to/test-charts
export HELM_DEBUG_SCRIPT=/path/to/helm_release_debug.sh
```

## Prerequisites

### Required Tools

```bash
# Core requirements
kubectl        # Kubernetes CLI
helm           # Helm 3.x
jq             # JSON processor

# For local testing
kind           # Kubernetes in Docker (optional)
docker         # Container runtime (for kind)
```

### Installation

```bash
# macOS
brew install kubectl helm jq kind

# Linux
# Install kubectl, helm, jq via package manager
# Install kind from https://kind.sigs.k8s.io/docs/user/quick-start/
```

## Cluster Types

### Auto Detection (Default)

The test runner automatically detects the best cluster type:

1. Checks for remote cluster configuration (SSH host or remote kubeconfig)
2. Falls back to kind if available
3. Uses existing kubectl context
4. Fails if no cluster available

### Kind (Local)

Creates ephemeral local Kubernetes cluster using Docker:

- **Pros**: Fast, isolated, reproducible
- **Cons**: Requires Docker, limited to single machine
- **Best for**: Local development, CI/CD

```bash
./run-tests.sh --cluster-type kind
```

### Remote

Connects to remote Kubernetes cluster via SSH or kubeconfig:

- **Pros**: Tests against real infrastructure
- **Cons**: Requires network access, leaves namespaces (unless torn down)
- **Best for**: Integration testing, staging validation

```bash
# Via SSH
./run-tests.sh --cluster-type remote \
  --remote-host user@k8s-host \
  --remote-ssh-key ~/.ssh/id_rsa

# Via kubeconfig
./run-tests.sh --cluster-type remote \
  --remote-kubeconfig /path/to/kubeconfig
```

### Existing

Uses current kubectl context:

- **Pros**: Quick, no setup needed
- **Cons**: May conflict with existing resources
- **Best for**: Quick validation, troubleshooting

```bash
./run-tests.sh --cluster-type existing --no-teardown
```

## Test Output

### Console Output

```
========================================
Test: HF-001 - Pre-Install Hook Failure
========================================
[INFO] Installing chart with failing pre-install hook...
[INFO] Running helm_release_debug.sh...
[PASS] Test HF-001 passed in 15s
  Detected pre-install hook failure (3/4 checks)

========================================
Test Summary
========================================
Total tests:   5
Passed:        5
Failed:        0
Skipped:       0
========================================
All tests passed
```

### Output Files

Test artifacts are saved to `$TEST_OUTPUT_DIR` (default: `/tmp/helm-debug-tests/`):

```
/tmp/helm-debug-tests/
├── HF-001/
│   ├── install.log          # Helm install output
│   ├── debug.log            # Debug script output
│   └── *.log                # Other command outputs
├── HF-002/
│   └── ...
└── ...
```

## Writing New Tests

### 1. Create Test Chart

Create chart in `test-charts/` with intentional failure:

```bash
mkdir -p test-charts/my-new-test/{templates,tests}
# Add Chart.yaml, values.yaml, templates, README.md
```

### 2. Document in Test Plan

Add scenario to `test-plan.md` with:
- Test ID and name
- Description
- Prerequisites
- Test steps
- Expected behavior
- Validation
- Cleanup

### 3. Implement Test Function

Add to `lib/test-implementations.sh`:

```bash
test_hf_003() {
    test_begin "HF-003" "Pre-Upgrade Hook Failure"

    local namespace="helm-test-hooks"
    local release="test-pre-upgrade"
    local chart="$TEST_CHARTS_DIR/hook-pre-upgrade-fail"
    local checks_passed=0

    # Test logic here...
    # Use assertion functions from test-framework.sh

    if [ $checks_passed -ge 3 ]; then
        test_end "pass" "Description"
        return 0
    else
        test_end "fail" "Only $checks_passed checks passed"
        return 1
    fi
}
```

### 4. Export and Run

```bash
# Add export at end of test-implementations.sh
export -f test_hf_003

# Run your test
./run-tests.sh --test HF-003 --verbose
```

## Test Framework API

### Lifecycle Functions

```bash
test_begin "TEST-ID" "Test Name"
test_end "pass|fail|skip" "Message"
```

### Assertions

```bash
assert_command_succeeds "description" command args...
assert_command_fails "description" command args...
assert_helm_release_status release namespace status
assert_helm_release_exists release namespace
assert_pod_status namespace labels status
assert_job_status namespace labels succeeded|failed|active
assert_output_contains file pattern description
assert_output_not_contains file pattern description
```

### Cleanup

```bash
cleanup_helm_release release namespace
cleanup_namespace_resources namespace
```

### Utilities

```bash
wait_for_condition "description" timeout "check_command"
log_info "message"
log_success "message"
log_error "message"
log_verbose "message"
```

## Troubleshooting

### Tests Fail to Start

```bash
# Verify prerequisites
kubectl version
helm version
kind version  # if using kind

# Check cluster connectivity
kubectl cluster-info
kubectl get nodes
```

### Test Hangs

```bash
# Run with verbose output
./run-tests.sh --test HF-001 --verbose

# Check cluster resources
kubectl get all --all-namespaces | grep helm-test

# Force cleanup
./run-tests.sh --teardown-only
```

### Kind Cluster Issues

```bash
# List clusters
kind get clusters

# Delete stuck cluster
kind delete cluster --name helm-debug-test

# Verify Docker
docker ps
docker system df
```

### Remote Cluster Connection

```bash
# Test SSH connection
ssh -i ~/.ssh/key user@host "kubectl cluster-info"

# Verify kubeconfig
kubectl --kubeconfig=/path/to/config get nodes

# Check permissions
kubectl auth can-i create pods --all-namespaces
```

### Cleanup Stuck Resources

```bash
# Force delete namespaces
kubectl delete namespace helm-test-hooks --force --grace-period=0

# Remove finalizers
kubectl patch namespace helm-test-hooks -p '{"metadata":{"finalizers":null}}'

# Clean all test resources
for ns in helm-test-{hooks,states,validation,dryrun,tests}; do
  kubectl delete namespace $ns --force --grace-period=0
done
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Helm Debug Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install tools
        run: |
          curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
          chmod +x /usr/local/bin/kind
          curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

      - name: Run tests
        run: |
          cd skills-testing/k8s-troubleshooter/helm-debugging
          ./run-tests.sh --verbose

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: /tmp/helm-debug-tests/
```

### GitLab CI Example

```yaml
helm-debug-tests:
  image: alpine:latest
  before_script:
    - apk add --no-cache curl bash jq
    - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  script:
    - cd skills-testing/k8s-troubleshooter/helm-debugging
    - ./run-tests.sh --cluster-type existing --kubeconfig $KUBECONFIG --verbose
  artifacts:
    when: always
    paths:
      - /tmp/helm-debug-tests/
```

## Related Documentation

- [Test Plan](test-plan.md) - Detailed 30-scenario test plan
- [Test Charts README](test-charts/README.md) - Test chart documentation
- [Helm Debugging Reference](/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/references/helm-debugging.md) - Helm debugging guide
- [helm_release_debug.sh Script](/Users/rbias/code/k8s4agents/skills/k8s-troubleshooter/scripts/helm_release_debug.sh) - The script being tested

## Contributing

When adding new tests:

1. Create test chart with clear failure mechanism
2. Document in test-plan.md
3. Implement test function in lib/test-implementations.sh
4. Test locally with `--verbose --no-cleanup`
5. Verify cleanup works properly
6. Submit PR with test chart, implementation, and documentation

## License

Part of the K8s4Agents project.

---

**Last Updated**: 2025-12-16
**Maintainer**: K8s4Agents Project
