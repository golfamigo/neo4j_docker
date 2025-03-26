# Use the official Neo4j image for importing data
FROM neo4j:5.25.1 as neo4j-import

# Create necessary directories for Neo4j
RUN mkdir -p /data /import

# 複製所有 CSV 文件到容器的 /import 目錄
COPY *.csv /import/

# 列出導入目錄中的文件以便調試
RUN ls -la /import/

# Import files based on what's available
RUN files_exist=false && \
    IMPORT_CMD="neo4j-admin database import full neo4j" && \
    for f in /import/*_nodes_import.csv; do \
        if [ -f "$f" ]; then \
            node_type=$(basename "$f" | sed 's/_nodes_import.csv//') && \
            IMPORT_CMD="$IMPORT_CMD --nodes=$node_type=$f"; \
            files_exist=true; \
            echo "添加節點文件: $f ($node_type)"; \
        fi; \
    done && \
    for f in /import/*_rel_import.csv; do \
        if [ -f "$f" ]; then \
            rel_type=$(basename "$f" | sed 's/_rel_import.csv//') && \
            IMPORT_CMD="$IMPORT_CMD --relationships=$f"; \
            files_exist=true; \
            echo "添加關係文件: $f ($rel_type)"; \
        fi; \
    done && \
    if [ "$files_exist" = true ]; then \
        echo "執行導入命令: $IMPORT_CMD" && \
        eval "$IMPORT_CMD" && \
        echo "Import completed successfully"; \
    else \
        echo "No CSV files available for import"; \
        ls -la /import/; \
    fi

# Second stage for running Neo4j with the preloaded data
FROM neo4j:5.25.1

# 正確格式的環境變數 - 使用小寫和下劃線
ENV NEO4J_AUTH=neo4j/password
ENV NEO4J_server_bolt_tls__level=DISABLED
ENV NEO4J_server_config_strict__validation_enabled=false
ENV NEO4J_PLUGINS='["apoc", "apoc-extended", "genai"]'

# 複製日誌配置文件
COPY server-logs.xml /var/lib/neo4j/conf/server-logs.xml
COPY user-logs.xml /var/lib/neo4j/conf/user-logs.xml

# Use the preloaded database from the import stage
COPY --from=neo4j-import /data /data

# Expose Neo4j ports
EXPOSE 7474 7687

# Run Neo4j
CMD ["neo4j"]
