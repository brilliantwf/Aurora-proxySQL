#!/bin/bash

# 测试ProxySQL连接池性能

PROXYSQL_PUBLIC_IP=""
KEY_PATH=""

# 帮助信息
function show_help {
  echo "用法: $0 <ProxySQL公网IP> <SSH密钥路径>"
  echo "示例: $0 12.34.56.78 /path/to/key.pem"
  exit 1
}

# 检查参数
if [ $# -lt 2 ]; then
  show_help
else
  PROXYSQL_PUBLIC_IP=$1
  KEY_PATH=$2
fi

echo "开始测试ProxySQL连接池性能..."
echo "连接到 $PROXYSQL_PUBLIC_IP 使用密钥 $KEY_PATH"

# 通过SSH连接到ProxySQL实例并执行测试
ssh -i "$KEY_PATH" ec2-user@$PROXYSQL_PUBLIC_IP << 'EOF'
echo "=== ProxySQL连接池测试 ==="

# 设置变量
DB_USER="proxysqluser"
DB_PASSWORD="{{YOUR_DB_PASSWORD}}"
DB_NAME="proxysqlexample"

# 创建测试表
echo "创建测试表..."
mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
DROP TABLE IF EXISTS connection_pool_test;
CREATE TABLE connection_pool_test (
  id INT AUTO_INCREMENT PRIMARY KEY,
  thread_id INT,
  iteration INT,
  connection_id VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# 测试函数：模拟多个并发连接
function test_connections {
  local num_connections=$1
  local iterations=$2
  
  echo "测试 $num_connections 个并发连接，每个连接执行 $iterations 次查询..."
  
  # 清空测试表
  mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "TRUNCATE TABLE connection_pool_test;"
  
  # 启动多个并发连接
  for i in $(seq 1 $num_connections); do
    (
      for j in $(seq 1 $iterations); do
        # 插入数据并获取连接ID
        mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
          INSERT INTO connection_pool_test (thread_id, iteration, connection_id) 
          VALUES ($i, $j, CONNECTION_ID());"
        
        # 随机休眠0-100毫秒，模拟真实工作负载
        sleep 0.$(printf "%03d" $((RANDOM % 100)))
      done
    ) &
  done
  
  # 等待所有后台任务完成
  wait
  
  # 分析结果
  echo "分析连接池使用情况..."
  
  # 获取使用的唯一连接数
  unique_connections=$(mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -N -e "
    SELECT COUNT(DISTINCT connection_id) FROM connection_pool_test;")
  
  # 获取总查询数
  total_queries=$(mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -N -e "
    SELECT COUNT(*) FROM connection_pool_test;")
  
  # 计算连接复用率
  reuse_ratio=$(echo "scale=2; $total_queries / $unique_connections" | bc)
  
  echo "结果:"
  echo "- 客户端连接数: $num_connections"
  echo "- 每个连接的查询数: $iterations"
  echo "- 总查询数: $total_queries"
  echo "- 使用的实际连接数: $unique_connections"
  echo "- 连接复用率: $reuse_ratio 查询/连接"
  
  # 获取ProxySQL连接池统计信息
  echo ""
  echo "ProxySQL连接池统计:"
  mysql -u admin -padmin -h 127.0.0.1 -P 6032 -t -e "SELECT * FROM stats.stats_mysql_connection_pool;"
}

# 测试不同的并发连接数
echo ""
echo "=== 测试场景1: 10个并发连接，每个执行10次查询 ==="
test_connections 10 10

echo ""
echo "=== 测试场景2: 50个并发连接，每个执行20次查询 ==="
test_connections 50 20

echo ""
echo "=== 测试场景3: 100个并发连接，每个执行5次查询 ==="
test_connections 100 5

# 获取ProxySQL全局状态
echo ""
echo "=== ProxySQL全局状态 ==="
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -t -e "SHOW MYSQL STATUS;"

# 获取ProxySQL连接池配置
echo ""
echo "=== ProxySQL连接池配置 ==="
mysql -u admin -padmin -h 127.0.0.1 -P 6032 -t -e "
  SELECT variable_name, variable_value 
  FROM global_variables 
  WHERE variable_name LIKE 'mysql-max%' 
     OR variable_name LIKE 'mysql-%connection%'
     OR variable_name LIKE 'mysql-multiplexing%';"

echo ""
echo "连接池测试完成！"
EOF

echo "测试脚本执行完毕！"
