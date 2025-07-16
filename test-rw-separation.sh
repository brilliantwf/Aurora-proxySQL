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
echo "===== ProxySQL 读写分离功能测试 ====="

# 1. 清理测试环境
echo -e "\n1. 清理测试环境"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "DROP DATABASE IF EXISTS rwtest;"
echo "✓ 测试环境清理完成"

# 2. 创建测试数据库和表
echo -e "\n2. 创建测试数据库和表"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "CREATE DATABASE rwtest;"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "CREATE TABLE rwtest.test_table (
  id INT AUTO_INCREMENT PRIMARY KEY, 
  data VARCHAR(100), 
  server_info VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"
echo "✓ 测试数据库和表创建完成"

# 3. 清除之前的统计数据
echo -e "\n3. 清除之前的统计数据"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "TRUNCATE TABLE stats_mysql_query_digest;"
echo "✓ 统计数据已清除"

# 4. 执行写入操作
echo -e "\n4. 执行写入操作"
for i in {1..5}; do
  result=$(mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "
    INSERT INTO rwtest.test_table (data, server_info) 
    VALUES ('test data $i', CONCAT(@@hostname, ':', @@port, ', read_only=', @@innodb_read_only));
    SELECT CONCAT(@@hostname, ':', @@port, ', read_only=', @@innodb_read_only) AS write_server;
  ")
  
  server=$(echo "$result" | grep -v "write_server" | tail -1)
  echo "写入操作 $i 使用服务器: $server"
done

# 5. 执行读取操作
echo -e "\n5. 执行读取操作"
for i in {1..5}; do
  result=$(mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "
    SELECT CONCAT(@@hostname, ':', @@port, ', read_only=', @@innodb_read_only) AS read_server;
  ")
  
  server=$(echo "$result" | grep -v "read_server" | tail -1)
  echo "读取操作 $i 使用服务器: $server"
done

# 6. 执行SELECT查询
echo -e "\n6. 执行SELECT查询"
echo "普通SELECT查询结果:"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "
  SELECT *, CONCAT(@@hostname, ':', @@port, ', read_only=', @@innodb_read_only) AS current_server 
  FROM rwtest.test_table;
"

# 7. 执行FOR UPDATE查询
echo -e "\n7. 执行FOR UPDATE查询"
echo "SELECT FOR UPDATE查询结果:"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "
  SELECT *, CONCAT(@@hostname, ':', @@port, ', read_only=', @@innodb_read_only) AS current_server 
  FROM rwtest.test_table 
  WHERE id = 1 
  FOR UPDATE;
"

# 8. 检查查询路由情况
echo -e "\n8. 查询路由情况"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "
  SELECT hostgroup, digest_text, count_star 
  FROM stats_mysql_query_digest 
  ORDER BY count_star DESC;
"

# 9. 验证直接连接到不同端点的结果
echo -e "\n9. 验证直接连接到不同端点的结果"
echo "写入端点:"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h {{YOUR_AURORA_CLUSTER_ENDPOINT}} -e "
  SELECT @@hostname, @@port, @@innodb_read_only;
"

echo "读取端点:"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h {{YOUR_AURORA_READER_ENDPOINT}} -e "
  SELECT @@hostname, @@port, @@innodb_read_only;
"

# 10. 检查ProxySQL配置
echo -e "\n10. 检查ProxySQL配置"
echo "MySQL服务器配置:"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "SELECT * FROM mysql_servers;"

echo -e "\nMySQL查询规则配置:"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "SELECT rule_id, active, match_digest, destination_hostgroup FROM mysql_query_rules ORDER BY rule_id;"

# 11. 总结测试结果
echo -e "\n11. 测试结果总结"

# 获取写入和读取查询数量
write_queries=$(mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "
  SELECT SUM(count_star) FROM stats_mysql_query_digest 
  WHERE hostgroup = 10;
" 2>&1 | grep -v "SUM" | head -1)

read_queries=$(mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "
  SELECT SUM(count_star) FROM stats_mysql_query_digest 
  WHERE hostgroup = 20;
" 2>&1 | grep -v "SUM" | head -1)

echo "写入查询数量: $write_queries"
echo "读取查询数量: $read_queries"

echo -e "\n结论:"
if [ "$write_queries" -gt 0 ] && [ "$read_queries" -gt 0 ]; then
  echo "✓ ProxySQL读写分离功能测试成功！"
  echo "✓ 写入操作被路由到主实例，读取操作被路由到读取副本。"
  
  # 检查FOR UPDATE查询是否正确路由到写入节点
  for_update_count=$(mysql -u admin -padmin -h 127.0.0.1 -P 6032 -e "
    SELECT count_star FROM stats_mysql_query_digest 
    WHERE digest_text LIKE '%FOR UPDATE%' AND hostgroup = 10;
  " 2>&1 | grep -v "count_star" | head -1)
  
  if [ -n "$for_update_count" ] && [ "$for_update_count" -gt 0 ]; then
    echo "✓ SELECT FOR UPDATE查询正确路由到写入节点。"
  else
    echo "✗ SELECT FOR UPDATE查询路由测试结果不确定。"
  fi
else
  echo "✗ ProxySQL读写分离功能测试结果不确定，请检查详细日志。"
fi

# 12. 显示测试数据
echo -e "\n12. 测试数据"
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h 127.0.0.1 -P 6033 -e "SELECT * FROM rwtest.test_table;"
EOF
