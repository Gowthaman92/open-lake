# Open Lake

## Overview

This repository contains scripts and deployment configurations for setting up and running the open lake, including the Hive Metastore and Jupyter Notebook. Follow the steps below to set up and deploy the platform.


### Step 1: Configure Environment Variables

1. Copy the example environment file to create your development environment configuration:

   cp open-lake/.env.example open-lake/.env

   Update the AZURE_STORAGE_KEY with correct key


2. Update the azure.access-key with correct key in trino/values.yaml


### Step 2: Deploy Services

./deploy-open-lake.sh

### Step 3: open http://localhost:8080/

### Step 4: sign up using login  and create a new password


## Cleaning up

### Use the following command to delete the created cluster

./clean.sh
