#!/bin/bash

# 设置变量
BUCKET_NAME="your-s3-bucket-name"
STACK_NAME="aurora-cluster-stack"
REGION="us-east-1"
VPC_ID=""
SUBNET_IDS=""
DB_NAME="proxysqlexample"
DB_USERNAME="proxysqluser"
DB_PASSWORD="pr0xySQL01Cred"
DB_INSTANCE_CLASS="db.r6g.large"

# 检查参数
if [ $# -lt 5 ]; then
  echo "用法: $0 <S3存储桶名称> <堆栈名称> <AWS区域> <VPC ID> <子网ID列表(逗号分隔)> [数据库名称] [用户名] [密码] [实例类型]"
  echo "示例: $0 my-bucket aurora-stack us-east-1 vpc-12345678 subnet-1234,subnet-5678 mydb dbuser dbpass db.r6g.large"
  exit 1
fi

# 从命令行参数获取值
BUCKET_NAME=$1
STACK_NAME=$2
REGION=$3
VPC_ID=$4
SUBNET_IDS=$5

# 可选参数
if [ $# -ge 6 ]; then
  DB_NAME=$6
fi

if [ $# -ge 7 ]; then
  DB_USERNAME=$7
fi

if [ $# -ge 8 ]; then
  DB_PASSWORD=$8
fi

if [ $# -ge 9 ]; then
  DB_INSTANCE_CLASS=$9
fi

# 创建临时目录
TMP_DIR=$(mktemp -d)
echo "创建临时目录: $TMP_DIR"

# 复制模板文件到临时目录
cp aurora-cluster.yaml $TMP_DIR/

# 上传模板文件到S3
echo "上传模板文件到S3..."
aws s3 cp $TMP_DIR/aurora-cluster.yaml s3://$BUCKET_NAME/proxysql-deploy/aurora-cluster.yaml --region $REGION

# 创建CloudFormation堆栈
echo "创建Aurora集群堆栈: $STACK_NAME..."
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-url https://s3.amazonaws.com/$BUCKET_NAME/proxysql-deploy/aurora-cluster.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=$VPC_ID \
    ParameterKey=DBSubnetIds,ParameterValue=\"$SUBNET_IDS\" \
    ParameterKey=DBName,ParameterValue=$DB_NAME \
    ParameterKey=DBUsername,ParameterValue=$DB_USERNAME \
    ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD \
    ParameterKey=DBInstanceClass,ParameterValue=$DB_INSTANCE_CLASS \
  --capabilities CAPABILITY_IAM \
  --region $REGION

# 等待堆栈创建完成
echo "等待Aurora集群堆栈创建完成..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

# 获取堆栈输出
echo "获取Aurora集群堆栈输出..."
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs" --output table

# 保存Aurora端点信息到文件
echo "保存Aurora端点信息到文件..."
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='ClusterEndpoint' || OutputKey=='ReaderEndpoint' || OutputKey=='DBName' || OutputKey=='DBUsername' || OutputKey=='SecurityGroupId']" --output json > aurora-endpoints.json

# 清理临时目录
echo "清理临时目录..."
rm -rf $TMP_DIR

echo "Aurora集群部署完成！"
