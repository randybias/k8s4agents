#!/usr/bin/env bash
# Cluster management library for Helm debugging tests

set -euo pipefail

# Cluster type detection and setup
# Supports: kind (local), remote (via KUBECONFIG/SSH)

# Global variables
CLUSTER_TYPE="${CLUSTER_TYPE:-auto}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-helm-debug-test}"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
REMOTE_SSH_HOST="${REMOTE_SSH_HOST:-}"
REMOTE_SSH_KEY="${REMOTE_SSH_KEY:-}"
REMOTE_KUBECONFIG="${REMOTE_KUBECONFIG:-}"

# Detect cluster type if set to auto
detect_cluster_type() {
    if [ "$CLUSTER_TYPE" != "auto" ]; then
        echo "$CLUSTER_TYPE"
        return 0
    fi

    # Check if we have remote cluster configuration
    if [ -n "$REMOTE_SSH_HOST" ] || [ -n "$REMOTE_KUBECONFIG" ]; then
        echo "remote"
        return 0
    fi

    # Check if kind is available
    if command -v kind >/dev/null 2>&1; then
        echo "kind"
        return 0
    fi

    # Default to using existing kubectl context
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "existing"
        return 0
    fi

    echo "none"
    return 1
}

# Setup kind cluster
setup_kind_cluster() {
    local cluster_name="$1"

    echo "Setting up kind cluster: $cluster_name"

    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${cluster_name}$"; then
        echo "Kind cluster '$cluster_name' already exists, using it"
        kind export kubeconfig --name "$cluster_name"
        return 0
    fi

    # Create new cluster
    echo "Creating new kind cluster..."
    cat <<EOF | kind create cluster --name "$cluster_name" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF

    # Export kubeconfig
    kind export kubeconfig --name "$cluster_name"

    # Wait for cluster to be ready
    echo "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s

    echo "Kind cluster '$cluster_name' is ready"
}

# Teardown kind cluster
teardown_kind_cluster() {
    local cluster_name="$1"

    echo "Tearing down kind cluster: $cluster_name"

    if kind get clusters 2>/dev/null | grep -q "^${cluster_name}$"; then
        kind delete cluster --name "$cluster_name"
        echo "Kind cluster '$cluster_name' deleted"
    else
        echo "Kind cluster '$cluster_name' does not exist, nothing to delete"
    fi
}

# Setup remote cluster connection
setup_remote_cluster() {
    echo "Setting up remote cluster connection"

    # If REMOTE_KUBECONFIG is provided, use it directly
    if [ -n "$REMOTE_KUBECONFIG" ]; then
        export KUBECONFIG="$REMOTE_KUBECONFIG"
        echo "Using KUBECONFIG: $REMOTE_KUBECONFIG"
    fi

    # If SSH host is provided, fetch kubeconfig via SSH
    if [ -n "$REMOTE_SSH_HOST" ]; then
        local ssh_opts=()
        if [ -n "$REMOTE_SSH_KEY" ]; then
            ssh_opts+=(-i "$REMOTE_SSH_KEY")
        fi

        echo "Fetching kubeconfig from remote host: $REMOTE_SSH_HOST"
        local temp_kubeconfig
        temp_kubeconfig=$(mktemp)

        # Fetch kubeconfig from remote
        ssh "${ssh_opts[@]}" "$REMOTE_SSH_HOST" "cat ~/.kube/config" > "$temp_kubeconfig"

        export KUBECONFIG="$temp_kubeconfig"
        echo "Using fetched KUBECONFIG: $temp_kubeconfig"
    fi

    # Verify connection
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "Successfully connected to remote cluster"
        kubectl cluster-info
        return 0
    else
        echo "ERROR: Failed to connect to remote cluster"
        return 1
    fi
}

# Setup existing cluster (use current kubectl context)
setup_existing_cluster() {
    echo "Using existing cluster from current kubectl context"

    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "ERROR: Cannot connect to existing cluster"
        return 1
    fi

    echo "Connected to cluster:"
    kubectl cluster-info
    return 0
}

# Main cluster setup function
setup_cluster() {
    local detected_type
    detected_type=$(detect_cluster_type)

    echo "Detected cluster type: $detected_type"

    case "$detected_type" in
        kind)
            setup_kind_cluster "$KIND_CLUSTER_NAME"
            ;;
        remote)
            setup_remote_cluster
            ;;
        existing)
            setup_existing_cluster
            ;;
        none)
            echo "ERROR: No cluster available. Please install kind or configure kubectl"
            return 1
            ;;
        *)
            echo "ERROR: Unknown cluster type: $detected_type"
            return 1
            ;;
    esac

    # Create test namespaces
    create_test_namespaces
}

# Teardown cluster
teardown_cluster() {
    local detected_type
    detected_type=$(detect_cluster_type)

    case "$detected_type" in
        kind)
            teardown_kind_cluster "$KIND_CLUSTER_NAME"
            ;;
        remote|existing)
            echo "Cleaning up test namespaces from remote/existing cluster"
            delete_test_namespaces
            ;;
        *)
            echo "No teardown needed for cluster type: $detected_type"
            ;;
    esac
}

# Create test namespaces
create_test_namespaces() {
    echo "Creating test namespaces..."

    local namespaces=(
        "helm-test-hooks"
        "helm-test-states"
        "helm-test-validation"
        "helm-test-dryrun"
        "helm-test-tests"
    )

    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            echo "Namespace '$ns' already exists"
        else
            kubectl create namespace "$ns"
            echo "Created namespace: $ns"
        fi
    done
}

# Delete test namespaces
delete_test_namespaces() {
    echo "Deleting test namespaces..."

    local namespaces=(
        "helm-test-hooks"
        "helm-test-states"
        "helm-test-validation"
        "helm-test-dryrun"
        "helm-test-tests"
    )

    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            echo "Deleting namespace: $ns"
            kubectl delete namespace "$ns" --wait=false
        fi
    done

    # Wait for deletion (with timeout)
    echo "Waiting for namespaces to be deleted..."
    local timeout=60
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local remaining=0
        for ns in "${namespaces[@]}"; do
            if kubectl get namespace "$ns" >/dev/null 2>&1; then
                ((remaining++))
            fi
        done

        if [ $remaining -eq 0 ]; then
            echo "All test namespaces deleted"
            return 0
        fi

        sleep 2
        ((elapsed+=2))
    done

    echo "WARNING: Some namespaces may still be terminating"
}

# Verify cluster is ready
verify_cluster_ready() {
    echo "Verifying cluster readiness..."

    # Check kubectl connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "ERROR: Cannot connect to cluster"
        return 1
    fi

    # Check if we can create resources
    if ! kubectl auth can-i create pods --all-namespaces >/dev/null 2>&1; then
        echo "WARNING: May not have sufficient permissions to create pods"
    fi

    # Check Helm
    if ! command -v helm >/dev/null 2>&1; then
        echo "ERROR: helm command not found"
        return 1
    fi

    echo "Cluster is ready for testing"
    return 0
}

# Export functions
export -f detect_cluster_type
export -f setup_kind_cluster
export -f teardown_kind_cluster
export -f setup_remote_cluster
export -f setup_existing_cluster
export -f setup_cluster
export -f teardown_cluster
export -f create_test_namespaces
export -f delete_test_namespaces
export -f verify_cluster_ready
