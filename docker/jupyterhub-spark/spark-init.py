#!/usr/bin/env python3

import os
import sys
import socket

# Get the hostname for Spark driver
hostname = socket.gethostname()
ip_address = socket.gethostbyname(hostname)

# Set environment variables for Spark
os.environ['PYSPARK_SUBMIT_ARGS'] = '--packages io.delta:delta-spark_2.12:3.2.0,org.apache.hadoop:hadoop-azure:3.3.4,com.amazonaws:aws-java-sdk-bundle:1.12.262,org.apache.hadoop:hadoop-aws:3.3.4 pyspark-shell'
os.environ['SPARK_DRIVER_HOST'] = ip_address

# Create a template for Spark initialization
spark_init_template = """
from pyspark.sql import SparkSession
import os
import socket

def get_spark_session(app_name="JupyterHub Spark", enable_hive=True, enable_delta=True):

    # Get environment variables
    driver_host = os.environ.get('SPARK_DRIVER_HOST', socket.gethostbyname(socket.gethostname()))
    hive_metastore_uri = os.environ.get('HIVE_METASTORE_URI', 'thrift://openlake-hive-metastore:9083')
    k8s_namespace = os.environ.get('NAMESPACE', 'default')
    
    # Start building the Spark session
    builder = SparkSession.builder.appName(app_name)
    
    # Configure Kubernetes
    builder = builder.config("spark.master", "k8s://https://kubernetes.default.svc") \\
        .config("spark.kubernetes.namespace", k8s_namespace) \\
        .config("spark.executor.instances", "2") \\
        .config("spark.executor.memory", "2g") \\
        .config("spark.executor.cores", "1") \\
        .config("spark.driver.memory", "2g") \\
        .config("spark.driver.cores", "1") \\
        .config("spark.kubernetes.container.image", "openlake/jupyterhub-spark:latest") \\
        .config("spark.kubernetes.authenticate.driver.serviceAccountName", "spark") \\
        .config("spark.driver.host", driver_host) \\
        .config("spark.driver.port", "29413")
    
    # Configure Delta Lake if enabled
    if enable_delta:
        builder = builder.config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \\
            .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    
    # Configure Hive if enabled
    if enable_hive:
        builder = builder.config("spark.sql.catalogImplementation", "hive") \\
            .config("hive.metastore.uris", hive_metastore_uri) \\
            .enableHiveSupport()
    
    # Configure cloud storage
    # AWS S3
    builder = builder.config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \\
        .config("spark.hadoop.fs.s3a.aws.credentials.provider", "com.amazonaws.auth.DefaultAWSCredentialsProviderChain")
    
    # Azure Blob Storage
    builder = builder.config("spark.hadoop.fs.azure.account.key.{account_name}.blob.core.windows.net", "{account_key}") \\
        .config("spark.hadoop.fs.azure.account.auth.type.{account_name}.dfs.core.windows.net", "OAuth") \\
        .config("spark.hadoop.fs.azure.account.oauth.provider.type.{account_name}.dfs.core.windows.net", "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider") \\
        .config("spark.hadoop.fs.azure.account.oauth2.client.id.{account_name}.dfs.core.windows.net", "{client_id}") \\
        .config("spark.hadoop.fs.azure.account.oauth2.client.secret.{account_name}.dfs.core.windows.net", "{client_secret}") \\
        .config("spark.hadoop.fs.azure.account.oauth2.client.endpoint.{account_name}.dfs.core.windows.net", "https://login.microsoftonline.com/{tenant_id}/oauth2/token")
    
    # Create and return the Spark session
    spark = builder.getOrCreate()
    
    # Set log level
    spark.sparkContext.setLogLevel("WARN")
    
    return spark

def get_delta_table(path, spark=None):
    from delta.tables import DeltaTable
    
    if spark is None:
        spark = get_spark_session()
    
    return DeltaTable.forPath(spark, path)
"""

# Write the template to a file
with open('/home/jovyan/spark_init.py', 'w') as f:
    f.write(spark_init_template)

print("Spark initialization template created at /home/jovyan/spark_init.py")

# Create a simple README file with usage instructions
readme_content = """# JupyterHub Spark Environment

This environment provides a JupyterHub instance with Spark and Hive integration.

## Getting Started

1. Import the Spark session creator:
   ```python
   from spark_init import get_spark_session
   ```

2. Create a Spark session:
   ```python
   spark = get_spark_session("My Application")
   ```

3. Use Spark with Hive:
   ```python
   # List databases
   spark.sql("SHOW DATABASES").show()
   
   # Create a table
   spark.sql("CREATE TABLE IF NOT EXISTS default.test (id INT, name STRING)")
   
   # Insert data
   spark.sql("INSERT INTO default.test VALUES (1, 'test')")
   
   # Query data
   spark.sql("SELECT * FROM default.test").show()
   ```

4. Use Delta Lake:
   ```python
   # Write data to Delta format
   df = spark.createDataFrame([(1, "test")], ["id", "name"])
   df.write.format("delta").save("/path/to/delta-table")
   
   # Read from Delta format
   df = spark.read.format("delta").load("/path/to/delta-table")
   ```

5. Access cloud storage:
   ```python
   # AWS S3
   df = spark.read.csv("s3a://bucket-name/path/to/file.csv")
   
   # Azure Blob Storage
   df = spark.read.csv("wasbs://container@account.blob.core.windows.net/path/to/file.csv")
   
   # Azure Data Lake Storage Gen2
   df = spark.read.csv("abfss://container@account.dfs.core.windows.net/path/to/file.csv")
   ```
"""

with open('/home/jovyan/README.md', 'w') as f:
    f.write(readme_content) 