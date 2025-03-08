#!/bin/bash
set -e

# deploy.sh
# This script handles the complete deployment process for the Hive Metastore,
# including setting up permissions, deleting existing resources, and applying new ones.
# Configuration
CLUSTER_NAME=open-lake
K_CONTEXT=${K_CONTEXT:-"kind-${CLUSTER_NAME}"}  # Default context, can be overridden
K_NS=${K_NS:-"default"}              # Default namespace, can be overridden
IMAGE_NAME=${IMAGE_NAME:-"hive"}   # Docker image name
IMAGE_TAG=${IMAGE_TAG:-"latest"}      # Docker image tag

# Function to build and load Docker image
build_and_load_image() {
    echo -e "${YELLOW}Building Docker image...${NC}"
    if ! docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .; then
        echo -e "${RED}Docker build failed${NC}"
        exit 1
    fi
    echo -e "${GREEN}Docker build completed${NC}"

    echo -e "${YELLOW}Loading image into Kind cluster...${NC}"
    if ! kind load docker-image ${IMAGE_NAME}:${IMAGE_TAG} --name $(echo $K_CONTEXT | sed 's/kind-//'); then
        echo -e "${RED}Failed to load image into Kind cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}Image loaded successfully${NC}"
}

# Function to ensure scripts have correct permissions
setup_permissions() {
    echo "Setting up script permissions..."
    # Make the generate-secrets script executable if it isn't already
    if [ ! -x "scripts/generate-secrets.sh" ]; then
        chmod +x scripts/generate-secrets.sh
        echo "Made generate-secrets.sh executable"
    fi
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed"
        exit 1
    fi
}

# Function to check deployment status
check_deployment_status() {
    echo "Waiting for deployment to be ready..."
    kubectl rollout status deployment/hive-metastore --timeout=300s
}

# Function to delete existing resources
delete_existing_resources() {
    echo "Deleting existing resources..."
    if kubectl get -f manifests/ &> /dev/null; then
        kubectl delete -f manifests/ || {
            echo "Warning: Failed to delete some resources. Continuing..."
        }
    else
        echo "No existing resources found to delete."
    fi
}


# Main deployment process
echo "Starting deployment..."

build_and_load_image

# Check prerequisites and setup
check_kubectl
setup_permissions

# Step 1: Delete existing resources
delete_existing_resources

# Step 2: Generate and apply secrets
echo "Generating secrets..."
if ! ./scripts/generate-secrets.sh ; then
    echo "Error: Failed to generate secrets"
    exit 1
fi

# Step 3: Apply all other resources
echo "Applying Kubernetes resources..."
if ! kubectl apply -f manifests/; then
    echo "Error: Failed to apply resources"
    exit 1
fi

# Step 4: Check deployment status
#check_deployment_status

echo "✨ Deployment Done! ✨"