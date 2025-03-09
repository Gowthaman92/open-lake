#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Uninstall Helm releases first
if helm list -q 2>/dev/null | grep -q "openlake"; then
  echo "Uninstalling OpenLake Helm release..."
  helm uninstall openlake
fi

# Delete the cluster
$SCRIPT_DIR/deploy-open-lake.sh clean
