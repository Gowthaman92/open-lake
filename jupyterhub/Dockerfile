FROM jupyterhub/singleuser:5.2.1

USER root

ARG DELTA_VERSION=3.2.0
ARG SCALA_VERSION=2.12
ARG ANTLR_VERSION=4.9.3

# Install basic dependencies
RUN apt-get update && \
    apt-get install -y wget curl gnupg software-properties-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install OpenJDK 8
RUN apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
# Set JAVA_HOME environment variable
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-${TARGETARCH}
ENV PATH=$JAVA_HOME/bin:$PATH

RUN wget https://archive.apache.org/dist/spark/spark-3.5.3/spark-3.5.3-bin-hadoop3.tgz && \
    tar -xzf spark-3.5.3-bin-hadoop3.tgz -C /opt/ && \
    rm spark-3.5.3-bin-hadoop3.tgz && \
    mv /opt/spark-3.5.3-bin-hadoop3 /opt/spark

RUN pip install pyspark==3.5.3

# Set SPARK_HOME environment variable
ENV SPARK_HOME=/opt/spark
ENV PATH=$SPARK_HOME/bin:$PATH

# Add JDBC driver and other dependencies to Spark's jars directory
RUN curl -L -o $SPARK_HOME/jars/postgresql-42.2.20.jar https://jdbc.postgresql.org/download/postgresql-42.2.20.jar && \
    curl -L -o $SPARK_HOME/jars/azure-storage-8.6.6.jar https://repo1.maven.org/maven2/com/microsoft/azure/azure-storage/8.6.6/azure-storage-8.6.6.jar && \
    curl -L -o $SPARK_HOME/jars/hadoop-azure-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/3.3.4/hadoop-azure-3.3.4.jar && \
    curl -L -o $SPARK_HOME/jars/hadoop-azure-datalake-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure-datalake/3.3.4/hadoop-azure-datalake-3.3.4.jar && \
    curl -L -o $SPARK_HOME/jars/azure-storage-blob-12.20.0.jar https://repo1.maven.org/maven2/com/azure/azure-storage-blob/12.20.0/azure-storage-blob-12.20.0.jar && \
    curl -L -o $SPARK_HOME/jars/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar && \
    curl -L -o $SPARK_HOME/jars/delta-storage-${DELTA_VERSION}.jar https://repo1.maven.org/maven2/io/delta/delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar && \
    curl -L -o $SPARK_HOME/jars/antlr4-runtime-${ANTLR_VERSION}.jar https://repo1.maven.org/maven2/org/antlr/antlr4-runtime/${ANTLR_VERSION}/antlr4-runtime-${ANTLR_VERSION}.jar && \
    curl -L -o $SPARK_HOME/jars/elasticsearch-spark-30_2.12-8.11.0.jar https://repo1.maven.org/maven2/org/elasticsearch/elasticsearch-spark-30_2.12/8.11.0/elasticsearch-spark-30_2.12-8.11.0.jar


# Change ownership of Spark directories to the Jupyter user
RUN chown -R $NB_UID:$NB_GID $SPARK_HOME
RUN chown $NB_UID:$NB_UID /opt/spark/jars/*

# Switch back to non-root user for Jupyter
USER $NB_UID

# Set working directory
WORKDIR /home/jovyan