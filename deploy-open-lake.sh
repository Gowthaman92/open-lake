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


helm repo add trino https://trinodb.github.io/charts
helm install -f trino/values.yaml trino trino/trino --kube-context=${KUBECTL_CONTEXT}


helm --kube-context=${KUBECTL_CONTEXT} repo ls | grep -e '^postgres-operator-charts ' || \
    helm --kube-context=${KUBECTL_CONTEXT} repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm --kube-context=${KUBECTL_CONTEXT} ls|grep -e '^postgres-operator ' || \
    helm --kube-context=${KUBECTL_CONTEXT} install postgres-operator postgres-operator-charts/postgres-operator
helm --kube-context=${KUBECTL_CONTEXT} repo ls | grep -e '^postgres-operator-ui-charts ' || \
    helm --kube-context=${KUBECTL_CONTEXT} repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm --kube-context=${KUBECTL_CONTEXT} ls|grep -e '^postgres-operator-ui\s' || \
    helm --kube-context=${KUBECTL_CONTEXT} install postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui
sleep 1
kubectl rollout status deploy/postgres-operator --context ${KUBECTL_CONTEXT}
kubectl apply -f postgres/database.yaml --context ${KUBECTL_CONTEXT}
sleep 1
kubectl wait --for=jsonpath='{.status.PostgresClusterStatus}'=Running postgresql/open-lake-postgres-cluster --timeout=300s --context ${KUBECTL_CONTEXT}

cd $SCRIPT_DIR/hive-metastore
./deploy.sh

cd ..

docker build -t spark:latest spark/

kind load docker-image spark:latest --name ${CLUSTER_NAME}

cd $SCRIPT_DIR/jupyterhub
./deploy.sh