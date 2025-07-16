#!/bin/bash

# 部署带连接池的ProxySQL实例

# 默认参数
BUCKET_NAME=""
STACK_NAME="proxysql-connection-pool-stack"
REGION="us-east-1"
VPC_ID=""
SUBNET_ID=""
KEY_NAME="your-key-pair-name"
AURORA_CLUSTER_ENDPOINT=""
AURORA_READER_ENDPOINT=""
ALLOWED_CIDR="0.0.0.0/0"
DB_NAME="proxysqlexample"
DB_USERNAME="proxysqluser"
DB_PASSWORD="{{YOUR_DB_PASSWORD}}"
INSTANCE_TYPE="m6in.xlarge"

# 连接池参数
MAX_CONNECTIONS=2000
MAX_CONNECTIONS_PER_USER=1000
CONNECTION_MAX_AGE_MS=3600000
FREE_CONNECTIONS_PCT=10
CONNECTION_DELAY_MULTIPLEX_MS=60000
MAX_TRANSACTION_TIME=1800000
MAX_QUERY_TIME=300000

# 帮助信息
function show_help {
  echo "用法: $0 <S3存储桶名称> <堆栈名称> <AWS区域> <VPC ID> <子网ID> <密钥对名称> <Aurora集群端点> <Aurora读取端点> [允许的CIDR] [数据库名称] [数据库用户名] [数据库密码] [实例类型] [最大连接数] [每用户最大连接数] [连接最大存活时间(ms)] [空闲连接百分比] [连接复用延迟(ms)] [最大事务时间(ms)] [最大查询时间(ms)]"
  echo "示例: $0 my-bucket proxysql-pool-stack us-east-1 vpc-12345678 subnet-1234 my-key-pair aurora-endpoint.rds.amazonaws.com aurora-reader.rds.amazonaws.com 1.2.3.4/32 mydb dbuser dbpass t3.large 2000 1000 3600000 10 60000 1800000 300000"
  exit 1
}

# 检查必要参数
if [ $# -lt 8 ]; then
  show_help
else
  BUCKET_NAME=$1
  STACK_NAME=$2
  REGION=$3
  VPC_ID=$4
  SUBNET_ID=$5
  KEY_NAME=$6
  AURORA_CLUSTER_ENDPOINT=$7
  AURORA_READER_ENDPOINT=$8
  
  # 可选参数
  if [ ! -z "$9" ]; then
    ALLOWED_CIDR=$9
  fi
  
  if [ ! -z "${10}" ]; then
    DB_NAME=${10}
  fi
  
  if [ ! -z "${11}" ]; then
    DB_USERNAME=${11}
  fi
  
  if [ ! -z "${12}" ]; then
    DB_PASSWORD=${12}
  fi
  
  if [ ! -z "${13}" ]; then
    INSTANCE_TYPE=${13}
  fi
  
  # 连接池可选参数
  if [ ! -z "${14}" ]; then
    MAX_CONNECTIONS=${14}
  fi
  
  if [ ! -z "${15}" ]; then
    MAX_CONNECTIONS_PER_USER=${15}
  fi
  
  if [ ! -z "${16}" ]; then
    CONNECTION_MAX_AGE_MS=${16}
  fi
  
  if [ ! -z "${17}" ]; then
    FREE_CONNECTIONS_PCT=${17}
  fi
  
  if [ ! -z "${18}" ]; then
    CONNECTION_DELAY_MULTIPLEX_MS=${18}
  fi
  
  if [ ! -z "${19}" ]; then
    MAX_TRANSACTION_TIME=${19}
  fi
  
  if [ ! -z "${20}" ]; then
    MAX_QUERY_TIME=${20}
  fi
fi

# 创建临时目录
TMP_DIR=$(mktemp -d)
cp proxysql-ec2-connection-pool.yaml $TMP_DIR/

# 上传模板到S3
echo "上传CloudFormation模板到S3..."
aws s3 cp $TMP_DIR/proxysql-ec2-connection-pool.yaml s3://$BUCKET_NAME/proxysql-deploy/proxysql-ec2-connection-pool.yaml --region $REGION

# 部署ProxySQL堆栈
echo "部署带连接池的ProxySQL堆栈..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-url https://s3.amazonaws.com/$BUCKET_NAME/proxysql-deploy/proxysql-ec2-connection-pool.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=SubnetId,ParameterValue=$SUBNET_ID \
    ParameterKey=KeyName,ParameterValue=$KEY_NAME \
    ParameterKey=AllowedCidrIngress,ParameterValue=$ALLOWED_CIDR \
    ParameterKey=AuroraClusterEndpoint,ParameterValue=$AURORA_CLUSTER_ENDPOINT \
    ParameterKey=AuroraReaderEndpoint,ParameterValue=$AURORA_READER_ENDPOINT \
    ParameterKey=DBName,ParameterValue=$DB_NAME \
    ParameterKey=DBUsername,ParameterValue=$DB_USERNAME \
    ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD \
    ParameterKey=InstanceType,ParameterValue=$INSTANCE_TYPE \
    ParameterKey=MaxConnections,ParameterValue=$MAX_CONNECTIONS \
    ParameterKey=MaxConnectionsPerUser,ParameterValue=$MAX_CONNECTIONS_PER_USER \
    ParameterKey=ConnectionMaxAgeMs,ParameterValue=$CONNECTION_MAX_AGE_MS \
    ParameterKey=FreeConnectionsPct,ParameterValue=$FREE_CONNECTIONS_PCT \
    ParameterKey=ConnectionDelayMultiplexMs,ParameterValue=$CONNECTION_DELAY_MULTIPLEX_MS \
    ParameterKey=MaxTransactionTime,ParameterValue=$MAX_TRANSACTION_TIME \
    ParameterKey=MaxQueryTime,ParameterValue=$MAX_QUERY_TIME \
  --capabilities CAPABILITY_IAM \
  --region $REGION

# 清理临时文件
rm -rf $TMP_DIR

echo "ProxySQL连接池堆栈部署已启动，请在AWS CloudFormation控制台检查部署状态。"
echo "堆栈名称: $STACK_NAME"
echo "区域: $REGION"

# 等待堆栈创建完成
echo "等待堆栈创建完成..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

# 获取输出
echo "获取ProxySQL连接池端点信息..."
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='ProxySQLPublicIP' || OutputKey=='ProxySQLPublicDNS' || OutputKey=='ProxySQLMySQLEndpoint' || OutputKey=='ProxySQLAdminEndpoint']" --output json > proxysql-connection-pool-endpoints.json

echo "ProxySQL连接池部署完成！端点信息已保存到 proxysql-connection-pool-endpoints.json"
cat proxysql-connection-pool-endpoints.json
