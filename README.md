# Open Lake

Open Lake is a data lakehouse platform deployed on Kubernetes, providing integrated components for data storage, processing, and analytics.

## Components

- **PostgreSQL**: Database for metadata storage
- **Hive Metastore**: Metadata service for data catalog
- **Trino**: Distributed SQL query engine
- **JupyterHub**: Interactive notebook environment

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

## Quick Start

### Deploy the Platform

```bash
# Deploy Open Lake
./deploy-open-lake.sh

# Clean deployment
./deploy-open-lake.sh clean

# Uninstall Open Lake
./deploy-open-lake.sh uninstall
```

## Required Values

Make storage and database configuration in chart/hive-metastore/required-values.yaml

### Storage Configuration

#### For Azure Deployment

Choose ONE of the following options:

##### Option 1: Direct storage key (development only)
```yaml
storage:
  type: azure
  azure:
    storageAccount: "mystorageaccount"
    containerName: "mycontainer"
    storageKey: "your-storage-key"
```

##### Option 2: Using Existing Secret
```yaml
storage:
  type: azure
  azure:
    storageAccount: "mystorageaccount"
    containerName: "mycontainer"
    existingSecret:
      name: "my-storage-secret"
      key: "storage-key"
```

### Database Configuration

Choose ONE of the following options:

##### Option 1: Internal PostgreSQL (default, no change needed)
```yaml
database:
  mode: "internal"
```

##### Option 2: External PostgreSQL
```yaml
database:
  mode: "external"
  external:
    host: "my-postgres.example.com"
    port: "5432"
    name: "metastore_db"
    user: "hive"
    password: "mypassword"
```

## Configuration Guide

### Storage Configuration

#### Azure Storage Configuration

##### Option 1: Direct Configuration
```yaml
storage:
  type: azure
  azure:
    storageAccount: "mystorageaccount"
    containerName: "mycontainer"
    storageKey: "your-storage-key"
```

##### Option 2: Using Existing Secret
First, create your Kubernetes secret:
```bash
# Create a Kubernetes secret named 'my-storage-secret'
# The secret will store your storage key under the key name 'storage-key'
kubectl create secret generic azure-storage-secret \
  --from-literal=storage-key='storage-key'
```

Then configure Hive Metastore to use this secret:
```yaml
storage:
  type: azure
  azure:
    storageAccount: "mystorageaccount"
    containerName: "mycontainer"
    existingSecret:
      # Reference the secret name you created above
      name: "my-storage-secret"
      # Reference the key name used in the secret
      # In this example, we used 'storage-key' when creating the secret
      key: "storage-key"
```

### Database Configuration

#### External Database Configuration

##### Option 1: Direct Configuration
```yaml
database:
  mode: "external"
  external:
    host: "my-postgres.example.com"
    port: "5432"
    name: "metastore_db"
    user: "postgres"
    password: "your-password"
```

##### Option 2: Using Existing Secret
First, create your Kubernetes secret:
```bash
# Create a Kubernetes secret named 'my-db-secret'
# The secret will store your database password under the key name 'password'
kubectl create secret generic my-db-secret \
  --from-literal=password='your-password'
```

Then configure the database to use this secret:
```yaml
database:
  mode: "external"
  external:
    host: "my-postgres.example.com"
    port: "5432"
    name: "metastore_db"
    user: "postgres"
    existingSecret:
      # Reference the secret name you created above
      name: "my-db-secret"
      # Reference the key name used in the secret
      # In this example, we used 'password' when creating the secret
      key: "password"
```

