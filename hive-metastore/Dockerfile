FROM ubuntu:22.04

ARG TARGETARCH

# Set up environment variables early, so they're available throughout the build
ENV JAVA_HOME=/usr/lib/jvm/temurin-8-jdk-${TARGETARCH} \
    HADOOP_HOME=/opt/hadoop \
    HIVE_HOME=/opt/hive
ENV PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HIVE_HOME/bin:$PATH \
    HADOOP_VERSION=3.3.4 \
    HIVE_VERSION=3.1.2

# Install essential packages in a single layer to keep the image size small
RUN apt-get update && \
    apt-get install -y \
    wget \
    apt-transport-https \
    curl \
    gnupg \
    gettext-base \
    netcat-openbsd \
    procps && \
    # Clean up apt cache to reduce image size
    rm -rf /var/lib/apt/lists/*

# Install Java
RUN wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - && \
    echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | \
    tee /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y temurin-8-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Check that JAVA_HOME exists
RUN [ -d "${JAVA_HOME}" ]

# Create directories first
RUN mkdir -p /opt/hadoop /opt/hive

# Download and extract Hadoop - now using wget instead of curl for better error handling
RUN wget -O hadoop.tar.gz https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar xzf hadoop.tar.gz --strip-components=1 -C /opt/hadoop && \
    rm hadoop.tar.gz

# Download and extract Hive
RUN wget -O hive.tar.gz https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    tar xzf hive.tar.gz --strip-components=1 -C /opt/hive && \
    rm hive.tar.gz

# Download Azure dependencies
RUN curl -L -o /opt/hive/lib/azure-storage-8.6.6.jar https://repo1.maven.org/maven2/com/microsoft/azure/azure-storage/8.6.6/azure-storage-8.6.6.jar && \
    curl -L -o /opt/hive/lib/hadoop-azure-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure/3.3.4/hadoop-azure-3.3.4.jar && \
    curl -L -o /opt/hive/lib/hadoop-azure-datalake-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-azure-datalake/3.3.4/hadoop-azure-datalake-3.3.4.jar && \
    curl -L -o /opt/hive/lib/azure-storage-blob-12.20.0.jar https://repo1.maven.org/maven2/com/azure/azure-storage-blob/12.20.0/azure-storage-blob-12.20.0.jar

# Create a non-root user for running Hive
RUN groupadd -r hive && \
    useradd -r -g hive -m -d /home/hive hive && \
    chown -R hive:hive /opt/hadoop /opt/hive

# Set up HDFS directories
RUN mkdir -p /opt/hadoop/dfs/name && \
    mkdir -p /opt/hadoop/dfs/data && \
    chown -R hive:hive /opt/hadoop/dfs

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost 9083 || exit 1

USER hive
EXPOSE 9083
WORKDIR /opt/hive

CMD ["hive", "--service", "metastore"]