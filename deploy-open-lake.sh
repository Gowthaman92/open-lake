#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CLUSTER_NAME=open-lake
KUBECTL_CONTEXT=kind-${CLUSTER_NAME}
BUILD_IMAGES=${BUILD_IMAGES:-"true"}    # Default to true for local development
PUSH_IMAGES=${PUSH_IMAGES:-"false"}     # Changed default to false

if [ "$1" == "clean" ]; then
    kind delete cluster -n ${CLUSTER_NAME}
    exit 0
fi

if [ "$1" == "uninstall" ]; then
    echo "Uninstalling all components without deleting the Kind cluster..."
    
    helm uninstall jupyterhub --kube-context=${KUBECTL_CONTEXT} 2>/dev/null || echo "JupyterHub not found"

    kubectl delete pod -l app=jupyterhub --context=${KUBECTL_CONTEXT} 2>/dev/null || echo "JupyterHub pods not found"
    # Uninstall Hive Metastore
    helm uninstall hive-metastore --kube-context=${KUBECTL_CONTEXT} 2>/dev/null || echo "Hive Metastore not found"
    
    # Uninstall Trino
    helm uninstall trino --kube-context=${KUBECTL_CONTEXT} 2>/dev/null || echo "Trino not found"
    
    # Uninstall Postgres
    kubectl delete postgresql openlake-postgres-cluster --context=${KUBECTL_CONTEXT} 2>/dev/null || echo "Postgres cluster not found"
    helm uninstall postgres --kube-context=${KUBECTL_CONTEXT} 2>/dev/null || echo "Postgres operator not found"
    
    echo "All components uninstalled. Kind cluster is still running."
    exit 0
fi

# Check if cluster already exists
if kind get clusters | grep -q "${CLUSTER_NAME}"; then
    echo "Cluster '${CLUSTER_NAME}' already exists, skipping creation."
else
    echo "Creating cluster '${CLUSTER_NAME}'..."
    kind create cluster -n ${CLUSTER_NAME}
fi

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm repo add trino https://trinodb.github.io/charts
helm repo update

# Build dependencies for the postgres chart
echo "Building Helm dependencies for postgres chart..."
rm -f $SCRIPT_DIR/charts/postgres/Chart.lock 2>/dev/null || true
helm dependency update $SCRIPT_DIR/charts/postgres

# Install Postgres Operator using Helm
echo "Installing Postgres Operator using Helm..."
helm upgrade --install postgres $SCRIPT_DIR/charts/postgres \
  -f $SCRIPT_DIR/charts/postgres/values.yaml \
  --kube-context=${KUBECTL_CONTEXT}

# Wait for Postgres Operator to be ready
echo "Waiting for Postgres Operator to be ready..."
kubectl wait --for=condition=available deployment/postgres-postgres-operator --timeout=300s --context=${KUBECTL_CONTEXT}

# Wait for PostgreSQL cluster to be ready
echo "Waiting for PostgreSQL cluster to be ready..."
kubectl wait --for=condition=established crd/postgresqls.acid.zalan.do --timeout=60s --context=${KUBECTL_CONTEXT}
kubectl wait --for=jsonpath='{.status.PostgresClusterStatus}'=Running postgresql/openlake-postgres-cluster --timeout=300s --context=${KUBECTL_CONTEXT}

# Build dependencies for the hive-metastore chart
echo "Building Helm dependencies for hive-metastore chart..."
rm -f $SCRIPT_DIR/charts/hive-metastore/Chart.lock 2>/dev/null || true
helm dependency update $SCRIPT_DIR/charts/hive-metastore

# Build and load images if needed
if [ "$BUILD_IMAGES" == "true" ]; then
  # Build and load Hive Metastore image
  echo "Building Hive Metastore image..."
  docker build -t hive-metastore:latest $SCRIPT_DIR/docker/hive-metastore
  
  echo "Loading Hive Metastore image into Kind cluster..."
  kind load docker-image hive-metastore:latest --name ${CLUSTER_NAME}
  
  # Build and load JupyterHub image
  echo "Building JupyterHub image..."
  docker build -t jupyterhub-spark-singleuser:latest -f $SCRIPT_DIR/docker/jupyterhub/Dockerfile $SCRIPT_DIR/docker/jupyterhub
  
  echo "Loading JupyterHub image into Kind cluster..."
  kind load docker-image jupyterhub-spark-singleuser:latest --name ${CLUSTER_NAME}
  
  # Push images if needed
  if [ "$PUSH_IMAGES" == "true" ]; then
    echo "Pushing Hive Metastore image..."
    docker push hive-metastore:latest
    
    echo "Pushing JupyterHub image..."
    docker push jupyterhub-spark-singleuser:latest
  fi
fi

# Install/upgrade Hive Metastore with both required and optional values
helm upgrade --install hive-metastore $SCRIPT_DIR/charts/hive-metastore \
  -f $SCRIPT_DIR/charts/hive-metastore/required-values.yaml \
  -f $SCRIPT_DIR/charts/hive-metastore/values.yaml \
  --kube-context=${KUBECTL_CONTEXT}

# Wait for Hive Metastore to be ready
echo "Waiting for Hive Metastore to be ready..."
kubectl wait --for=condition=available deployment/openlake-hive-metastore --timeout=300s --context=${KUBECTL_CONTEXT}

# Install Trino
echo "====================================================="
echo "  Deploying Trino"
echo "====================================================="

# Install/upgrade Trino using the official chart
echo "Installing Trino using official Helm chart..."
helm upgrade --install trino trino/trino \
  -f $SCRIPT_DIR/charts/trino/values.yaml \
  --kube-context=${KUBECTL_CONTEXT}

# Wait for Trino to be ready
echo "Waiting for Trino to be ready..."
kubectl wait --for=condition=available deployment/trino-coordinator --timeout=300s --context=${KUBECTL_CONTEXT}

# Build and deploy JupyterHub
echo "====================================================="
echo "  Deploying JupyterHub with Spark"
echo "====================================================="

# Build dependencies for the JupyterHub chart
echo "Building Helm dependencies for JupyterHub chart..."
rm -f $SCRIPT_DIR/charts/jupyterhub/Chart.lock 2>/dev/null || true
helm dependency update $SCRIPT_DIR/charts/jupyterhub

# Install/upgrade JupyterHub
echo "Installing JupyterHub using Helm..."
helm upgrade --install jupyterhub $SCRIPT_DIR/charts/jupyterhub \
  -f $SCRIPT_DIR/charts/jupyterhub/values.yaml \
  --kube-context=${KUBECTL_CONTEXT}

# Wait for JupyterHub to be ready
echo "Waiting for JupyterHub to be ready..."
wait_for_jupyter() {
    echo "Waiting for Jupyter Hub pod to be ready..."

    local timeout=300  # Total timeout in seconds
    local interval=5   # Polling interval in seconds
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        # Check if any pod with the correct labels is in 'Ready' state
        if kubectl -n default get pods \
            -l app=jupyterhub,component=hub \
            -o jsonpath='{.items[?(@.status.phase=="Running")].status.conditions[?(@.type=="Ready")].status}' \
            --context=${KUBECTL_CONTEXT} | grep -q "True"; then
            echo "Jupyter Hub pod is ready!"
            return 0
        fi

        # Wait before retrying
        sleep $interval
        elapsed=$((elapsed + interval))
        echo "Still waiting... ($elapsed/$timeout seconds elapsed)"
    done

    echo "Timeout waiting for Jupyter Hub pod to become ready."
    return 1
}

# Call the wait function
wait_for_jupyter

# Offer to set up port forwarding
port_forward_jupyter() {
    echo "Starting port-forwarding for JupyterHub service..."

    # Start port-forwarding in the background
    kubectl port-forward service/proxy-public 8080:http --context=${KUBECTL_CONTEXT} > /dev/null 2>&1 &

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
        return 1
    fi

    # Keep the port-forwarding running
    wait $PORT_FORWARD_PID
}

echo "====================================================="
echo "  Open Lake deployment completed!"
echo "====================================================="
echo "Setting up port forwarding to JupyterHub..."
port_forward_jupyter
echo "====================================================="