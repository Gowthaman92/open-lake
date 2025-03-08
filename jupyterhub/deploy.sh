#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"open-lake"}  # Allow override via environment
K_CONTEXT=${K_CONTEXT:-"kind-${CLUSTER_NAME}"}
K_NS=${K_NS:-"default"}
IMAGE_NAME=${IMAGE_NAME:-"jupyter"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}
HELM_VERSION=${HELM_VERSION:-"4.0.0"}
CONFIG_FILE=${CONFIG_FILE:-"config.yaml"}

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Function to check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    for tool in docker kind kubectl curl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
}

# Function to build and load Docker image
build_and_load_image() {
    log_info "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}..."
    if ! docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .; then
        log_error "Docker build failed"
        return 1
    fi
    log_info "Docker build completed"

    local cluster_name
    cluster_name=$(echo "$K_CONTEXT" | sed 's/kind-//')
    
    log_info "Loading image into Kind cluster..."
    if ! kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "$cluster_name"; then
        log_error "Failed to load image into Kind cluster"
        return 1
    fi
    log_info "Image loaded successfully"
}

# Function to check kubectl context
check_context() {
    if ! kubectl config get-contexts "$K_CONTEXT" &> /dev/null; then
        log_error "Kubernetes context '$K_CONTEXT' not found"
        return 1
    fi
    log_info "Using Kubernetes context: $K_CONTEXT"
}

# Function to create namespace if it doesn't exist
ensure_namespace() {
    if ! kubectl --context "$K_CONTEXT" get namespace "$K_NS" &> /dev/null; then
        log_info "Creating namespace $K_NS..."
        kubectl --context "$K_CONTEXT" create namespace "$K_NS"
    else
        log_info "Using existing namespace: $K_NS"
    fi
}

# Function to install/update Helm
setup_helm() {
    if ! command -v helm &> /dev/null; then
        log_info "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    fi
    
    helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/ || true
    helm repo update
}

# Function to deploy Jupyter resources
deploy_jupyter() {
    log_info "Deploying Jupyter resources..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file $CONFIG_FILE not found"
        return 1
    fi
    
    helm upgrade --install jhub jupyterhub/jupyterhub \
        --namespace "$K_NS" \
        --values "$CONFIG_FILE" \
        --version "$HELM_VERSION"
}

# Function to cleanup resources
cleanup_resources() {
    log_info "Cleaning up existing Jupyter resources..."
    helm uninstall jhub --namespace "$K_NS" 2>/dev/null || true
}

# Function to wait for Jupyter deployment
wait_for_jupyter() {
    echo "Waiting for Jupyter Hub pod to be ready..."

    local timeout=300  # Total timeout in seconds
    local interval=5   # Polling interval in seconds
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        # Check if any pod with the correct labels is in 'Ready' state
        if kubectl --context $K_CONTEXT -n $K_NS get pods \
            -l app=jupyterhub,component=hub \
            -o jsonpath='{.items[?(@.status.phase=="Running")].status.conditions[?(@.type=="Ready")].status}' \
            | grep -q "True"; then
            echo "Jupyter Hub pod is ready!"
            return 0
        fi

        # Wait before retrying
        sleep $interval
        elapsed=$((elapsed + interval))
        echo "Still waiting... ($elapsed/$timeout seconds elapsed)"
    done

    echo "Timeout waiting for Jupyter Hub pod to become ready."
    exit 1
}


port_forward_jupyter() {
    echo "Starting port-forwarding for JupyterHub service..."

    # Start port-forwarding in the background
    kubectl --namespace=default port-forward service/proxy-public 8080:http > /dev/null 2>&1 &

    # Capture the process ID of the port-forwarding command
    PORT_FORWARD_PID=$!

    # Wait a moment to ensure the port-forwarding is set up
    sleep 3

    # Check if port-forwarding succeeded
    if ps -p $PORT_FORWARD_PID > /dev/null; then
        echo -e "\033[0;32m[INFO]\033[0m Port-forwarding is active. Access JupyterHub at:"
        echo -e "\033[0;34mhttp://localhost:8080\033[0m"
        echo "Press Ctrl+C to stop port-forwarding when you're done."
    else
        echo -e "\033[0;31m[ERROR]\033[0m Port-forwarding failed. Please check your Kubernetes setup."
        exit 1
    fi

    # Keep the port-forwarding running
    wait $PORT_FORWARD_PID
}

# Main execution
main() {
    log_info "Starting Jupyter deployment..."
    
    check_prerequisites
    check_context
    ensure_namespace
    setup_helm
    
    # Build and load Docker image
    build_and_load_image
    
    # Cleanup existing resources
    cleanup_resources
    
    kubectl apply -f rbac.yaml
    # Deploy resources
    deploy_jupyter
    wait_for_jupyter
    port_forward_jupyter

    log_info "Deployment completed successfully!"
}

# Trap errors
trap 'log_error "An error occurred. Exiting..." >&2' ERR

# Execute main function
main "$@"