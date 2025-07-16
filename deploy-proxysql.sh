#!/bin/bash

# 设置变量
BUCKET_NAME="your-s3-bucket-name"
STACK_NAME="proxysql-ec2-stack"
REGION="us-east-1"
VPC_ID=""
SUBNET_ID=""
KEY_NAME="your-key-pair-name"
ALLOWED_CIDR="0.0.0.0/0"  # 建议限制为您的IP地址
AURORA_CLUSTER_ENDPOINT=""
AURORA_READER_ENDPOINT=""
DB_NAME="proxysqlexample"
DB_USERNAME="proxysqluser"
DB_PASSWORD="pr0xySQL01Cred"
INSTANCE_TYPE="t3.large"

# 检查参数
if [ $# -lt 7 ]; then
  echo "用法: $0 <S3存储桶名称> <堆栈名称> <AWS区域> <VPC ID> <子网ID> <密钥对名称> <Aurora集群端点> <Aurora读取端点> [允许的CIDR] [数据库名称] [用户名] [密码] [实例类型]"
  echo "示例: $0 my-bucket proxysql-stack us-east-1 vpc-12345678 subnet-1234 my-key-pair aurora-endpoint.rds.amazonaws.com aurora-reader.rds.amazonaws.com 1.2.3.4/32 mydb dbuser dbpass t3.large"
  exit 1
fi

# 从命令行参数获取值
BUCKET_NAME=$1
STACK_NAME=$2
REGION=$3
VPC_ID=$4
SUBNET_ID=$5
KEY_NAME=$6
AURORA_CLUSTER_ENDPOINT=$7
AURORA_READER_ENDPOINT=$8

# 可选参数
if [ $# -ge 9 ]; then
  ALLOWED_CIDR=$9
fi

if [ $# -ge 10 ]; then
  DB_NAME=${10}
fi

if [ $# -ge 11 ]; then
  DB_USERNAME=${11}
fi

if [ $# -ge 12 ]; then
  DB_PASSWORD=${12}
fi

if [ $# -ge 13 ]; then
  INSTANCE_TYPE=${13}
fi

# 创建临时目录
TMP_DIR=$(mktemp -d)
echo "创建临时目录: $TMP_DIR"

# 复制模板文件到临时目录
cp proxysql-ec2.yaml $TMP_DIR/

# 上传模板文件到S3
echo "上传模板文件到S3..."
aws s3 cp $TMP_DIR/proxysql-ec2.yaml s3://$BUCKET_NAME/proxysql-deploy/proxysql-ec2.yaml --region $REGION

# 创建CloudFormation堆栈
echo "创建ProxySQL堆栈: $STACK_NAME..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-url https://s3.amazonaws.com/$BUCKET_NAME/proxysql-deploy/proxysql-ec2.yaml \
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
  --capabilities CAPABILITY_IAM \
  --region $REGION

# 等待堆栈创建完成
echo "等待ProxySQL堆栈创建完成..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

# 获取堆栈输出
echo "获取ProxySQL堆栈输出..."
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs" --output table

# 保存ProxySQL端点信息到文件
echo "保存ProxySQL端点信息到文件..."
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='ProxySQLPublicIP' || OutputKey=='ProxySQLPublicDNS' || OutputKey=='ProxySQLMySQLEndpoint' || OutputKey=='ProxySQLAdminEndpoint']" --output json > proxysql-endpoints.json

# 清理临时目录
echo "清理临时目录..."
rm -rf $TMP_DIR

echo "ProxySQL部署完成！"
