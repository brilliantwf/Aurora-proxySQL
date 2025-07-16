#!/bin/bash

# 设置变量
PROXYSQL_PUBLIC_IP=""
KEY_PATH=""

# 检查参数
if [ $# -lt 2 ]; then
  echo "用法: $0 <ProxySQL公网IP> <SSH密钥路径>"
  echo "示例: $0 12.34.56.78 /path/to/key.pem"
  exit 1
fi

# 从命令行参数获取值
PROXYSQL_PUBLIC_IP=$1
KEY_PATH=$2

# 在ProxySQL实例上执行测试命令
ssh -i "$KEY_PATH" ec2-user@$PROXYSQL_PUBLIC_IP << 'EOF'
echo "===== 验证ProxySQL写入操作路由 ====="

# 1. 清理测试环境
echo -e "\n1. 清理测试环境"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "DROP DATABASE IF EXISTS writetest;"
echo "✓ 测试环境清理完成"

# 2. 创建测试数据库和表
echo -e "\n2. 创建测试数据库和表"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "CREATE DATABASE writetest;"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "CREATE TABLE writetest.server_info (
  id INT AUTO_INCREMENT PRIMARY KEY, 
  operation VARCHAR(100),
  hostname VARCHAR(100),
  port INT,
  read_only INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"
echo "✓ 测试数据库和表创建完成"

# 3. 清除之前的统计数据
echo -e "\n3. 清除之前的统计数据"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "TRUNCATE TABLE stats_mysql_query_digest;"
echo "✓ 统计数据已清除"

# 4. 执行写入操作，直接在INSERT语句中获取服务器信息
echo -e "\n4. 执行写入操作，直接在INSERT语句中获取服务器信息"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "
  INSERT INTO writetest.server_info (operation, hostname, port, read_only) 
  VALUES ('INSERT', @@hostname, @@port, @@innodb_read_only);
"
echo "✓ 写入操作完成"

# 5. 查看写入的数据
echo -e "\n5. 查看写入的数据"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "
  SELECT * FROM writetest.server_info;
"

# 6. 直接连接到写入端点和读取端点进行验证
echo -e "\n6. 直接连接到写入端点和读取端点进行验证"
echo "写入端点:"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h {{YOUR_AURORA_CLUSTER_ENDPOINT}} -e "
  SELECT @@hostname, @@port, @@innodb_read_only;
"

echo "读取端点:"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h {{YOUR_AURORA_READER_ENDPOINT}} -e "
  SELECT @@hostname, @@port, @@innodb_read_only;
"

# 7. 检查查询路由情况
echo -e "\n7. 检查查询路由情况"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "
  SELECT hostgroup, digest_text, count_star 
  FROM stats_mysql_query_digest 
  ORDER BY count_star DESC;
"

# 8. 结论
echo -e "\n8. 结论"
write_server=$(mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "
  SELECT hostname, port, read_only FROM writetest.server_info WHERE operation='INSERT';
" | grep -v "hostname" | head -1)

primary_server=$(mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h {{YOUR_AURORA_CLUSTER_ENDPOINT}} -e "
  SELECT @@hostname, @@port, @@innodb_read_only;
" | grep -v "@@hostname" | head -1)

echo "写入操作执行的服务器: $write_server"
echo "主实例服务器: $primary_server"

if [ "$write_server" = "$primary_server" ]; then
  echo "✓ 验证成功：写入操作确实被路由到了主实例！"
else
  echo "✗ 验证失败：写入操作没有被路由到主实例。"
fi
EOF
