# Use the official Neo4j image for importing data
FROM neo4j:5.25.1 as neo4j-import

# Set environment variables
ARG NODE_CSV_URLS=""
ARG RELATION_CSV_URLS=""

ENV NODE_CSV_URLS=${NODE_CSV_URLS}
ENV RELATION_CSV_URLS=${RELATION_CSV_URLS}

# Create necessary directories for Neo4j
RUN mkdir -p /data /import

# Install curl to download the CSV files
RUN apt-get update && apt-get install -y curl

# Create download and process scripts
COPY <<-'EOF' /download.sh
#!/bin/bash
validate_and_download() {
    url=$1
    output=$2
    description=$3
    
    if [ -z "$url" ]; then
        return 1
    fi
    
    echo "Validating $description URL: $url"
    http_code=$(curl -L --connect-timeout 10 --max-time 30 -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$http_code" = "200" ]; then
        echo "URL is valid. Downloading $description..."
        if curl -L --connect-timeout 10 --max-time 30 -f -o "$output" "$url"; then
            if [ -s "$output" ]; then
                echo "$description downloaded successfully"
                return 0
            fi
        fi
    fi
    
    echo "Warning: Failed to download $description from $url"
    rm -f "$output"
    return 1
}

process_urls() {
    urls=$1
    type=$2
    counter=1
    success=false
    
    if [ -n "$urls" ]; then
        echo "Processing URLs for $type: $urls"
        IFS=',' read -ra URL_ARRAY <<< "$urls"
        for url in "${URL_ARRAY[@]}"; do
            url=$(echo "$url" | tr -d '[:space:]')
            if [ -n "$url" ]; then
                output="/import/${type}_${counter}.csv"
                if validate_and_download "$url" "$output" "${type^} CSV $counter"; then
                    success=true
                    ((counter++))
                fi
            fi
        done
    fi
    
    [ "$success" = true ]
}

# Process node URLs
if [ -n "$NODE_CSV_URLS" ]; then
    process_urls "$NODE_CSV_URLS" "node"
fi

# Process relation URLs
if [ -n "$RELATION_CSV_URLS" ]; then
    process_urls "$RELATION_CSV_URLS" "relation"
fi
EOF

RUN chmod +x /download.sh && /download.sh

# Import files based on what's available
RUN files_exist=false && \
    IMPORT_CMD="neo4j-admin database import full neo4j" && \
    for f in /import/node_*.csv; do \
        if [ -f "$f" ]; then \
            node_type=$(basename "$f" | sed -E 's/node_([0-9]+)\.csv/Node\1/') && \
            IMPORT_CMD="$IMPORT_CMD --nodes=${node_type}=$f"; \
            files_exist=true; \
        fi; \
    done && \
    for f in /import/relation_*.csv; do \
        if [ -f "$f" ]; then \
            rel_type=$(basename "$f" | sed -E 's/relation_([0-9]+)\.csv/Relation\1/') && \
            IMPORT_CMD="$IMPORT_CMD --relationships=${rel_type}=$f"; \
            files_exist=true; \
        fi; \
    done && \
    if [ "$files_exist" = true ]; then \
        echo "Executing: $IMPORT_CMD" && \
        eval "$IMPORT_CMD" && \
        echo "Import completed successfully"; \
    else \
        echo "No CSV files available for import"; \
    fi

# Second stage for running Neo4j with the preloaded data
FROM neo4j:5.25.1

ARG DB_PASSWORD=""

# Set environment variables for Neo4j
ENV NEO4J_AUTH=neo4j/${DB_PASSWORD}
# Disable TLS/SSL for Bolt connection
ENV NEO4J_dbms_connector_bolt_tls__level=DISABLED
ENV NEO4J_dbms_connector_bolt_listen__address=:7687
# Allow remote connections
ENV NEO4J_dbms_default__listen__address=0.0.0.0
ENV NEO4J_dbms_connector_http_listen__address=:7474

RUN echo "NEO4J_AUTH=${DB_PASSWORD}"

# Use the preloaded database from the import stage
COPY --from=neo4j-import /data /data

# Copy log configuration if these files exist
COPY server-logs.xml /var/lib/neo4j/conf/server-logs.xml
COPY user-logs.xml /var/lib/neo4j/conf/user-logs.xml

# Expose Neo4j ports
EXPOSE 7474 7687

# Run Neo4j
CMD ["neo4j"]
