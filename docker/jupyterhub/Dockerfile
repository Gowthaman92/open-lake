FROM jupyterhub/singleuser:5.3.0

USER root

# Install additional packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-11-jdk \
    curl \
    wget \
    krb5-user \
    libkrb5-dev \
    libsasl2-dev \
    libsasl2-modules-gssapi-mit \
    unzip \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables first
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

# Install Spark
ARG SPARK_VERSION=3.5.3
ARG HADOOP_VERSION=3.3.4
ARG DELTA_VERSION=3.2.0
ARG SCALA_VERSION=2.12
ARG AWS_SDK_VERSION=1.12.262
ARG AZURE_STORAGE_VERSION=3.3.4

# Download and install Spark
RUN wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz -C /opt && \
    ln -s /opt/spark-${SPARK_VERSION}-bin-hadoop3 /opt/spark && \
    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Update PYTHONPATH after Spark is installed
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip:$PYTHONPATH

# Create jars directory first
RUN mkdir -p $SPARK_HOME/jars

# Download AWS S3 integration JARs
RUN wget -q https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar -P $SPARK_HOME/jars/

# Download Azure Storage integration JARs
RUN wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/${HADOOP_VERSION}/hadoop-azure-${HADOOP_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget -q https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure-datalake/${HADOOP_VERSION}/hadoop-azure-datalake-${HADOOP_VERSION}.jar -P $SPARK_HOME/jars/ && \
    wget -q https://repo1.maven.org/maven2/com/microsoft/azure/azure-storage/8.6.6/azure-storage-8.6.6.jar -P $SPARK_HOME/jars/

# Download Delta Lake JARs
RUN curl -L -o $SPARK_HOME/jars/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar && \
    curl -L -o $SPARK_HOME/jars/delta-storage-${DELTA_VERSION}.jar https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar

# Download Hive dependencies
RUN wget -q https://repo1.maven.org/maven2/org/apache/hive/hive-metastore/3.1.3/hive-metastore-3.1.3.jar -P $SPARK_HOME/jars/ && \
    wget -q https://repo1.maven.org/maven2/org/apache/hive/hive-exec/3.1.3/hive-exec-3.1.3.jar -P $SPARK_HOME/jars/

# Download JDBC drivers
RUN wget -q https://repo1.maven.org/maven2/org/postgresql/postgresql/42.5.1/postgresql-42.5.1.jar -P $SPARK_HOME/jars/ && \
    wget -q https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.30/mysql-connector-java-8.0.30.jar -P $SPARK_HOME/jars/

# Install Python packages
RUN pip install --upgrade pip setuptools
RUN pip install --no-cache-dir \
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

# Create directory for Hive configuration
RUN mkdir -p /etc/hive/conf

# Switch back to jovyan user
USER jovyan