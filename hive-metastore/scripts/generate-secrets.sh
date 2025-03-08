#!/bin/bash

# Usage: ./generate-secrets.sh <environment>
# Example: ./generate-secrets.sh dev


ENV_FILE=".env"
ENV_EXAMPLE_FILE=".env.example"

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file not found: $ENV_FILE"
    echo "Create a new environment file by copying the template .env.example and put a proper AZURE_STORAGE_KEY there"
    exit 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a



# Generate secret from template
envsubst < templates/hive-secrets-template.yaml > "hive-secrets.yaml"

# Apply the secret to Kubernetes
echo "Applying secret to Kubernetes cluster..."
kubectl apply -f "hive-secrets.yaml"


echo "Secrets successfully generated and applied"