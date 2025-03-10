## Required Values

### For Azure Deployment
1. Storage Configuration (ONE of the following):
   ```yaml
   # Option 1: Direct storage key (development only)
   storage:
     type: azure
     azure:
       storageAccount: "mystorageaccount"
       containerName: "mydatalake"
       storageKey: "your-storage-key"

   # Option 2: Existing secret (recommended)
   storage:
     type: azure
     azure:
       storageAccount: "mystorageaccount"
       containerName: "mydatalake"
       existingSecret: "azure-storage-secret" # Name of the Kubernetes secret containing the storage key
       secretKey: "azure-storage-key" # Key in the secret that contains the storage key value
   ```

### Database Configuration (ONE of the following):
   ```yaml
   # Option 1: Internal PostgreSQL (default)
   database:
     mode: "internal"

   # Option 2: External PostgreSQL
   database:
     mode: "external"
     external:
       host: "my-postgres.example.com"
       port: "5432"
       name: "metastore_db"
       user: "hive"
       password: "mypassword"
   ``` 