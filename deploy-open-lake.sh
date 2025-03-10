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
    
    # Uninstall JupyterHub
    cd $SCRIPT_DIR/jupyterhub
    ./undeploy.sh 2>/dev/null || echo "JupyterHub undeploy failed or not found"
    cd $SCRIPT_DIR
    
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

# Build and load Hive Metastore image if needed
if [ "$BUILD_IMAGES" == "true" ]; then
  echo "Building Hive Metastore image..."
  docker build -t hive-metastore:latest ./hive-metastore
  
  echo "Loading image into Kind cluster..."
  kind load docker-image hive-metastore:latest --name ${CLUSTER_NAME}
  
  if [ "$PUSH_IMAGES" == "true" ]; then
    echo "Pushing Hive Metastore image..."
    docker push hive-metastore:latest
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