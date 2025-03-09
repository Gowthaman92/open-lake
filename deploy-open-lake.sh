#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CLUSTER_NAME=open-lake
KUBECTL_CONTEXT=kind-${CLUSTER_NAME}

if [ "$1" == "clean" ]; then
    kind delete cluster -n ${CLUSTER_NAME}
    exit 0
fi

if [ "$1" == "uninstall" ]; then
    echo "Uninstalling all components without deleting the Kind cluster..."
    
    # Uninstall JupyterHub
    cd $SCRIPT_DIR/jupyterhub
    ./undeploy.sh 2>/dev/null || echo "JupyterHub undeploy failed or not found"
    cd $SCRIPT_DIR
    
    # Uninstall Hive Metastore
    cd $SCRIPT_DIR/hive-metastore
    ./undeploy.sh 2>/dev/null || echo "Hive Metastore undeploy failed or not found"
    cd $SCRIPT_DIR
    
    # Uninstall Trino
    helm uninstall trino --kube-context=${KUBECTL_CONTEXT} 2>/dev/null || echo "Trino not found"
    
    # Uninstall Postgres
    kubectl delete postgresql openlake-postgres-cluster --context=${KUBECTL_CONTEXT} 2>/dev/null || echo "Postgres cluster not found"
    
    # Uninstall OpenLake
    helm uninstall openlake --kube-context=${KUBECTL_CONTEXT} 2>/dev/null || echo "OpenLake not found"
    
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
# First remove the lock file if it exists to force rebuild
rm -f $SCRIPT_DIR/charts/postgres/Chart.lock 2>/dev/null || true
helm dependency update $SCRIPT_DIR/charts/postgres

# Install Postgres using Helm
echo "Installing Postgres using Helm..."
helm install postgres $SCRIPT_DIR/charts/postgres \
  -f $SCRIPT_DIR/charts/postgres/values.yaml \
  --kube-context=${KUBECTL_CONTEXT}

# Wait for Postgres to be ready
echo "Waiting for Postgres to be ready..."
kubectl wait --for=jsonpath='{.status.PostgresClusterStatus}'=Running postgresql/openlake-postgres-cluster --timeout=300s --context=${KUBECTL_CONTEXT}