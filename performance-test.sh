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
echo "===== ProxySQL 读写分离性能测试 ====="

# 设置变量
DB_USER="proxysqluser"
DB_PASSWORD="pr0xySQL01Cred"
DB_NAME="proxysqlexample"
TEST_TABLE="load_test"
NUM_WRITERS=5                  # 写入进程数
NUM_READERS=10                 # 读取进程数
DURATION=60                   # 测试持续时间（秒）
REPORT_INTERVAL=5             # 报告间隔（秒）

# 创建测试表
echo "创建测试表..."
mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
CREATE TABLE IF NOT EXISTS $TEST_TABLE (
  id INT AUTO_INCREMENT PRIMARY KEY,
  data VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# 创建索引以提高查询性能
mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
CREATE INDEX IF NOT EXISTS idx_created_at ON $TEST_TABLE(created_at);"

# 初始化计数器
write_count=0
read_count=0

# 创建临时文件存储计数
WRITE_COUNT_FILE=$(mktemp)
READ_COUNT_FILE=$(mktemp)
echo "0" > $WRITE_COUNT_FILE
echo "0" > $READ_COUNT_FILE

# 写入函数
write_data() {
  local process_id=$1
  local end_time=$2
  local local_write_count=0
  
  while [ $(date +%s) -lt $end_time ]; do
    # 生成随机数据
    local random_data=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    
    # 插入数据
    mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
    INSERT INTO $TEST_TABLE (data) VALUES ('Writer-$process_id: $random_data');" &>/dev/null
    
    # 更新计数
    local_write_count=$((local_write_count + 1))
    
    # 随机休眠一小段时间（0-100毫秒）
    sleep 0.$(printf "%03d" $((RANDOM % 100)))
  done
  
  # 更新总写入计数
  current=$(cat $WRITE_COUNT_FILE)
  echo $((current + local_write_count)) > $WRITE_COUNT_FILE
}

# 读取函数
read_data() {
  local process_id=$1
  local end_time=$2
  local local_read_count=0
  
  while [ $(date +%s) -lt $end_time ]; do
    # 执行不同类型的查询
    case $((RANDOM % 5)) in
      0)
        # 简单查询
        mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
        SELECT COUNT(*) FROM $TEST_TABLE;" &>/dev/null
        ;;
      1)
        # 带条件的查询
        mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
        SELECT * FROM $TEST_TABLE ORDER BY id DESC LIMIT 10;" &>/dev/null
        ;;
      2)
        # 聚合查询
        mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
        SELECT DATE(created_at) as date, COUNT(*) as count FROM $TEST_TABLE GROUP BY DATE(created_at);" &>/dev/null
        ;;
      3)
        # 随机ID查询
        rand_id=$((RANDOM % 1000 + 1))
        mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
        SELECT * FROM $TEST_TABLE WHERE id > $rand_id LIMIT 20;" &>/dev/null
        ;;
      4)
        # 复杂查询
        mysql -h 127.0.0.1 -P 6033 -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
        SELECT SUBSTRING(data, 1, 10) as data_prefix, COUNT(*) as count 
        FROM $TEST_TABLE 
        GROUP BY data_prefix 
        ORDER BY count DESC 
        LIMIT 10;" &>/dev/null
        ;;
    esac
    
    # 更新计数
    local_read_count=$((local_read_count + 1))
    
    # 随机休眠一小段时间（0-50毫秒）
    sleep 0.$(printf "%03d" $((RANDOM % 50)))
  done
  
  # 更新总读取计数
  current=$(cat $READ_COUNT_FILE)
  echo $((current + local_read_count)) > $READ_COUNT_FILE
}

# 计算结束时间
END_TIME=$(($(date +%s) + DURATION))

# 启动写入进程
echo "启动 $NUM_WRITERS 个写入进程..."
for i in $(seq 1 $NUM_WRITERS); do
  write_data $i $END_TIME &
done

# 启动读取进程
echo "启动 $NUM_READERS 个读取进程..."
for i in $(seq 1 $NUM_READERS); do
  read_data $i $END_TIME &
done

# 定期报告进度
LAST_WRITE_COUNT=0
LAST_READ_COUNT=0
START_TIME=$(date +%s)

echo "测试开始，将持续 $DURATION 秒..."
echo "时间(秒) | 写入总数 | 写入/秒 | 读取总数 | 读取/秒 | 总操作/秒"
echo "---------|----------|---------|----------|---------|------------"

while [ $(date +%s) -lt $END_TIME ]; do
  sleep $REPORT_INTERVAL
  
  # 获取当前计数
  CURRENT_WRITE_COUNT=$(cat $WRITE_COUNT_FILE)
  CURRENT_READ_COUNT=$(cat $READ_COUNT_FILE)
  
  # 计算每秒操作数
  ELAPSED=$(($(date +%s) - START_TIME))
  WRITE_PER_SEC=$(echo "scale=2; $CURRENT_WRITE_COUNT / $ELAPSED" | bc)
  READ_PER_SEC=$(echo "scale=2; $CURRENT_READ_COUNT / $ELAPSED" | bc)
  TOTAL_PER_SEC=$(echo "scale=2; ($CURRENT_WRITE_COUNT + $CURRENT_READ_COUNT) / $ELAPSED" | bc)
  
  # 计算区间操作数
  INTERVAL_WRITES=$((CURRENT_WRITE_COUNT - LAST_WRITE_COUNT))
  INTERVAL_READS=$((CURRENT_READ_COUNT - LAST_READ_COUNT))
  INTERVAL_WRITE_PER_SEC=$(echo "scale=2; $INTERVAL_WRITES / $REPORT_INTERVAL" | bc)
  INTERVAL_READ_PER_SEC=$(echo "scale=2; $INTERVAL_READS / $REPORT_INTERVAL" | bc)
  INTERVAL_TOTAL_PER_SEC=$(echo "scale=2; ($INTERVAL_WRITES + $INTERVAL_READS) / $REPORT_INTERVAL" | bc)
  
  # 更新上次计数
  LAST_WRITE_COUNT=$CURRENT_WRITE_COUNT
  LAST_READ_COUNT=$CURRENT_READ_COUNT
  
  # 输出报告
  printf "%9s | %8s | %7s | %8s | %7s | %12s\n" \
    "$ELAPSED" \
    "$CURRENT_WRITE_COUNT" \
    "$INTERVAL_WRITE_PER_SEC" \
    "$CURRENT_READ_COUNT" \
    "$INTERVAL_READ_PER_SEC" \
    "$INTERVAL_TOTAL_PER_SEC"
done

# 等待所有后台进程完成
wait

# 最终报告
FINAL_WRITE_COUNT=$(cat $WRITE_COUNT_FILE)
FINAL_READ_COUNT=$(cat $READ_COUNT_FILE)
TOTAL_ELAPSED=$(($(date +%s) - START_TIME))
FINAL_WRITE_PER_SEC=$(echo "scale=2; $FINAL_WRITE_COUNT / $TOTAL_ELAPSED" | bc)
FINAL_READ_PER_SEC=$(echo "scale=2; $FINAL_READ_COUNT / $TOTAL_ELAPSED" | bc)
FINAL_TOTAL_PER_SEC=$(echo "scale=2; ($FINAL_WRITE_COUNT + $FINAL_READ_COUNT) / $TOTAL_ELAPSED" | bc)

echo ""
echo "测试完成！"
echo "总写入操作: $FINAL_WRITE_COUNT (平均 $FINAL_WRITE_PER_SEC 操作/秒)"
echo "总读取操作: $FINAL_READ_COUNT (平均 $FINAL_READ_PER_SEC 操作/秒)"
echo "总操作数: $((FINAL_WRITE_COUNT + FINAL_READ_COUNT)) (平均 $FINAL_TOTAL_PER_SEC 操作/秒)"

# 清理临时文件
rm -f $WRITE_COUNT_FILE $READ_COUNT_FILE

# 查询ProxySQL统计信息
echo ""
echo "ProxySQL查询路由统计:"
mysql -h 127.0.0.1 -P 6032 -u admin -padmin -e "
SELECT hostgroup, digest_text, count_star, sum_time 
FROM stats_mysql_query_digest 
ORDER BY count_star DESC 
LIMIT 20;"

# 检查ProxySQL连接统计
echo ""
echo "ProxySQL连接统计:"
mysql -h 127.0.0.1 -P 6032 -u admin -padmin -e "
SELECT * FROM stats_mysql_connection_pool;"
EOF
