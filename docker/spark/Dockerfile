FROM apache/spark:3.5.3

# Switch to root user for setup operations
USER root

# Define versions as build arguments for better maintainability
# This makes it easier to update versions in one place
ARG DELTA_VERSION=3.2.0
ARG SCALA_VERSION=2.12
ARG POSTGRES_VERSION=42.2.20
ARG AZURE_STORAGE_VERSION=8.6.6
ARG HADOOP_VERSION=3.3.4
ARG ANTLR_VERSION=4.9.3
ARG AWS_SDK_VERSION=1.12.262
ARG MYSQL_CONNECTOR_VERSION=8.0.30
ARG HIVE_VERSION=3.1.3

# First, let's install system dependencies and Python
# We combine these operations to reduce the number of layers and image size
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    wget && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.12 python3.12-dev python3.12-venv && \
    rm -rf /var/lib/apt/lists/* && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --set python3 /usr/bin/python3.12

# Install pip for Python 3.12 directly
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12

# Set Python environment variables
ENV PYSPARK_PYTHON=/usr/bin/python3 \
    PYSPARK_DRIVER_PYTHON=/usr/bin/python3

# Download all dependencies in a single layer
# This is more efficient than multiple RUN commands
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
    # AWS SDK Bundle
    curl -L -o aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar && \
    curl -L -o hadoop-aws-${HADOOP_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar && \
    # Delta Lake Dependencies
    curl -L -o delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar \
    https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar && \
    curl -L -o delta-storage-${DELTA_VERSION}.jar \
    https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar && \
    # Hive Metastore Dependencies
    curl -L -o hive-metastore-${HIVE_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hive/hive-metastore/${HIVE_VERSION}/hive-metastore-${HIVE_VERSION}.jar && \
    curl -L -o hive-exec-${HIVE_VERSION}.jar \
    https://repo1.maven.org/maven2/org/apache/hive/hive-exec/${HIVE_VERSION}/hive-exec-${HIVE_VERSION}.jar && \
    # Misc Dependencies
    curl -L -o antlr4-runtime-${ANTLR_VERSION}.jar \
    https://repo1.maven.org/maven2/org/antlr/antlr4-runtime/${ANTLR_VERSION}/antlr4-runtime-${ANTLR_VERSION}.jar && \
    curl -L -o elasticsearch-spark-30_2.12-8.11.0.jar \
    https://repo1.maven.org/maven2/org/elasticsearch/elasticsearch-spark-30_2.12/8.11.0/elasticsearch-spark-30_2.12-8.11.0.jar && \
    # MySQL JDBC Driver
    curl -L -o mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar \
    https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar

# Install Python packages
RUN python3.12 -m pip install --upgrade pip setuptools wheel
RUN python3.12 -m pip install --no-cache-dir \
    delta-spark==${DELTA_VERSION} \
    pyhive==0.7.0 \
    thrift==0.22.0 \
    thrift-sasl==0.4.3 \
    pyarrow==20.0.0 \
    pandas==2.3.1 \
    numpy==2.3.1 \
    matplotlib==3.10.3 \
    seaborn==0.13.2 \
    scikit-learn==1.7.0 \
    plotly==6.2.0 \
    ipywidgets==8.1.7 \
    boto3==1.39.4 \
    azure-storage-blob==12.25.1 \
    azure-identity==1.23.0 \
    sqlalchemy==2.0.19 \
    psycopg2-binary==2.9.10 \
    pymysql==1.1.1 \
    ipython-sql==0.5.0

# Create a directory for temporary data and set proper permissions
RUN mkdir -p /tmp/spark-events && \
    chown -R spark:spark /tmp/spark-events && \
    chown -R spark:spark /opt/spark/jars/*

# Add a health check to verify Spark's availability
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep org.apache.spark.deploy.master.Master | grep -v grep || exit 1

# Switch back to spark user for security
USER spark