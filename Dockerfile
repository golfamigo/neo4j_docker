# 使用官方 Neo4j 映像進行資料導入
FROM neo4j:5.25.1 as neo4j-import

# 安裝需要的工具
RUN apt-get update && apt-get install -y curl

# 創建必要的目錄
RUN mkdir -p /data /import /logs

# 複製所有 CSV 文件到容器的 /import 目錄
COPY *_nodes_import.csv /import/
COPY *_rel_import.csv /import/
COPY import.sh /import/

# 設置執行權限
RUN chmod +x /import/import.sh

# 執行導入腳本
RUN cd /import && ./import.sh

# 第二階段用於運行 Neo4j 和預載資料
FROM neo4j:5.25.1

ARG DB_PASSWORD="password"

# 設定環境變數
ENV NEO4J_AUTH=neo4j/${DB_PASSWORD}

# 使用預載的資料庫
COPY --from=neo4j-import /data /data

# 設定日誌配置 (如果需要)
# COPY server-logs.xml /var/lib/neo4j/conf/server-logs.xml
# COPY user-logs.xml /var/lib/neo4j/conf/user-logs.xml

# 暴露 Neo4j 端口
EXPOSE 7474 7687

# 運行 Neo4j
CMD ["neo4j"]
