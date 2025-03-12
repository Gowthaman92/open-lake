#!/bin/bash
set -e

# Configuration
IMAGE_NAME="jupyterhub-spark-singleuser"
IMAGE_TAG="latest"
NAMESPACE="default"  # Change this to your namespace if different
HELM_RELEASE_NAME="jupyterhub"
HELM_CHART_PATH="./charts/jupyterhub"
VALUES_FILE="charts/jupyterhub/values.yaml"
KIND_CLUSTER_NAME="open-lake"  # Default Kind cluster name


# Function to wait for Jupyter deployment
wait_for_jupyter() {
    echo "Waiting for Jupyter Hub pod to be ready..."

    local timeout=300  # Total timeout in seconds
    local interval=5   # Polling interval in seconds
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        # Check if any pod with the correct labels is in 'Ready' state
        if kubectl -n ${NAMESPACE} get pods \
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
    kubectl -n ${NAMESPACE} port-forward service/proxy-public 8080:http > /dev/null 2>&1 &

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

# Print banner
echo "====================================================="
echo "  Deploying JupyterHub with Spark to Kubernetes"
echo "====================================================="

# Build the Docker image
echo "[1/7] Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f docker/jupyterhub-spark/Dockerfile docker/jupyterhub-spark

echo "[2/7] Loading Docker image into Kind cluster"
kind load docker-image "${IMAGE_NAME}:${IMAGE_TAG}" --name "$KIND_CLUSTER_NAME"

# Build Helm dependencies
echo "[3/7] Building Helm chart dependencies"
cd charts/jupyterhub && helm dependency build && cd ../..

echo "[4/7] Installing JupyterHub Helm chart"
helm install ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} \
  --values ${VALUES_FILE} \
  --namespace ${NAMESPACE} \
  --create-namespace

echo "[5/7] Waiting for JupyterHub to be ready"
wait_for_jupyter

echo "[6/7] Setting up port forwarding"
port_forward_jupyter

# Print success message
echo "[7/7] Deployment completed"
echo "====================================================="
echo "  JupyterHub with Spark deployment completed!"
echo "====================================================="
echo "To access JupyterHub, run:"
echo "  kubectl get service proxy-public -n ${NAMESPACE}"
echo "And use the external IP or hostname to access JupyterHub."
echo "=====================================================" 