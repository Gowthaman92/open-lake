#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

CLUSTER_NAME=open-lake
KUBECTL_CONTEXT=kind-${CLUSTER_NAME}

if [ "$1" == "clean" ]; then
    kind delete cluster -n ${CLUSTER_NAME}
    exit 0
fi

kind create cluster -n ${CLUSTER_NAME}

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm repo add trino https://trinodb.github.io/charts
helm repo update

# Install OpenLake with Postgres using Helm
echo "Installing OpenLake with Postgres using Helm..."
helm install openlake $SCRIPT_DIR/charts/openlake \
  --set global.storage.key=$(grep AZURE_STORAGE_KEY .env | cut -d '=' -f2) \
  --kube-context=${KUBECTL_CONTEXT}

# Wait for Postgres to be ready
echo "Waiting for Postgres to be ready..."
kubectl wait --for=jsonpath='{.status.PostgresClusterStatus}'=Running postgresql/openlake-postgres-cluster --timeout=300s --context=${KUBECTL_CONTEXT}

# Continue with the rest of the deployment (to be converted to Helm later)
helm install -f trino/values.yaml trino trino/trino --kube-context=${KUBECTL_CONTEXT}

cd $SCRIPT_DIR/hive-metastore
./deploy.sh

cd ..

docker build -t spark:latest spark/

kind load docker-image spark:latest --name ${CLUSTER_NAME}

cd $SCRIPT_DIR/jupyterhub
./deploy.sh