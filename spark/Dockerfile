FROM apache/spark:3.5.3

# Switch to root user for setup operations
USER root

# Define versions as build arguments for better maintainability
ARG DELTA_VERSION=3.2.0
ARG SCALA_VERSION=2.12
ARG POSTGRES_VERSION=42.2.20
ARG AZURE_STORAGE_VERSION=8.6.6
ARG HADOOP_VERSION=3.3.4
ARG ANTLR_VERSION=4.9.3

# Install system dependencies and Python
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    wget \
    gettext-base && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.11 python3.11-dev python3-pip && \
    rm -rf /var/lib/apt/lists/* && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --set python3 /usr/bin/python3.11

# Set Python environment variables
ENV PYSPARK_PYTHON=/usr/bin/python3 \
    PYSPARK_DRIVER_PYTHON=/usr/bin/python3

# Download all dependencies in a single layer
RUN cd /opt/spark/jars && \
    # PostgreSQL JDBC Driver
    curl -L -o postgresql-${POSTGRES_VERSION}.jar \
    https://jdbc.postgresql.org/download/postgresql-${POSTGRES_VERSION}.jar && \
    # Azure Storage Dependencies
    curl -L -o azure-storage-${AZURE_STORAGE_VERSION}.jar \
    https://repo1.maven.org/maven2/com/microsoft/azure/azure-storage/${AZURE_STORAGE_VERSION}/azure-storage-${AZURE_STORAGE_VERSION}.jar && \
    curl -L -o hadoop-azure-${HADOOP_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/${HADOOP_VERSION}/hadoop-azure-${HADOOP_VERSION}.jar && \
    curl -L -o hadoop-azure-datalake-${HADOOP_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure-datalake/${HADOOP_VERSION}/hadoop-azure-datalake-${HADOOP_VERSION}.jar && \
    curl -L -o azure-storage-blob-12.20.0.jar \
    https://repo1.maven.org/maven2/com/azure/azure-storage-blob/12.20.0/azure-storage-blob-12.20.0.jar && \
    curl -L -o delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar \
    https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar && \
    curl -L -o delta-storage-${DELTA_VERSION}.jar \
    https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar && \
    curl -L -o antlr4-runtime-${ANTLR_VERSION}.jar \
    https://repo1.maven.org/maven2/org/antlr/antlr4-runtime/${ANTLR_VERSION}/antlr4-runtime-${ANTLR_VERSION}.jar && \
    curl -L -o elasticsearch-spark-30_2.12-8.11.0.jar \
    https://repo1.maven.org/maven2/org/elasticsearch/elasticsearch-spark-30_2.12/8.11.0/elasticsearch-spark-30_2.12-8.11.0.jar


# Create a directory for temporary data and set proper permissions
RUN mkdir -p /tmp/spark-events && \
    chown -R spark:spark /tmp/spark-events && \
    chown -R spark:spark /opt/spark/jars/*

# Add a wrapper script to process environment variables
COPY start-spark.sh /opt/spark/bin/start-spark.sh
RUN chmod +x /opt/spark/bin/start-spark.sh

# Add a health check to verify Spark's availability
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep org.apache.spark.deploy.master.Master | grep -v grep || exit 1

# Switch back to spark user for security
USER spark