#!/bin/bash

# 設定資料庫名稱
DB_NAME="neo4j"

# 確認 import 目錄存在
mkdir -p /import

# 建立導入命令
IMPORT_CMD="neo4j-admin database import full $DB_NAME"

# 添加所有節點文件
for f in /import/*_nodes_import.csv; do
  if [ -f "$f" ]; then
    node_type=$(basename "$f" | sed 's/_nodes_import.csv//')
    echo "添加節點文件: $f ($node_type)"
    IMPORT_CMD="$IMPORT_CMD --nodes=$node_type=$f"
  fi
done

# 添加所有關係文件
for f in /import/*_rel_import.csv; do
  if [ -f "$f" ]; then
    rel_type=$(basename "$f" | sed 's/_rel_import.csv//')
    echo "添加關係文件: $f ($rel_type)"
    IMPORT_CMD="$IMPORT_CMD --relationships=$f"
  fi
done

# 輸出完整導入命令
echo "執行導入命令: $IMPORT_CMD"

# 執行導入
eval "$IMPORT_CMD"

echo "導入操作完成"
