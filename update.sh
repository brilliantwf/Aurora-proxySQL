#!/bin/bash

# 设置变量
BUCKET_NAME="your-s3-bucket-name"
STACK_NAME="proxysql-stack"
REGION="us-east-1"
KEY_NAME="your-key-pair-name"
ALLOWED_CIDR="0.0.0.0/0"  # 建议限制为您的IP地址

# 检查参数
if [ $# -lt 3 ]; then
  echo "用法: $0 <S3存储桶名称> <堆栈名称> <AWS区域> [密钥对名称] [允许的CIDR]"
  echo "示例: $0 my-bucket proxysql-stack us-east-1 my-key-pair 1.2.3.4/32"
  exit 1
fi

# 从命令行参数获取值
BUCKET_NAME=$1
STACK_NAME=$2
REGION=$3

# 可选参数
if [ $# -ge 4 ]; then
  KEY_NAME=$4
fi

if [ $# -ge 5 ]; then
  ALLOWED_CIDR=$5
fi

# 创建临时目录
TMP_DIR=$(mktemp -d)
echo "创建临时目录: $TMP_DIR"

# 复制模板文件到临时目录
cp network.yaml $TMP_DIR/
cp aurora-cluster.yaml $TMP_DIR/
cp proxysql-ec2.yaml $TMP_DIR/

# 修改master.yaml中的S3存储桶名称
sed "s/BUCKET_NAME/$BUCKET_NAME/g" master.yaml > $TMP_DIR/master.yaml

# 上传模板文件到S3
echo "上传模板文件到S3..."
aws s3 cp $TMP_DIR/network.yaml s3://$BUCKET_NAME/proxysql-deploy/network.yaml --region $REGION
aws s3 cp $TMP_DIR/aurora-cluster.yaml s3://$BUCKET_NAME/proxysql-deploy/aurora-cluster.yaml --region $REGION
aws s3 cp $TMP_DIR/proxysql-ec2.yaml s3://$BUCKET_NAME/proxysql-deploy/proxysql-ec2.yaml --region $REGION
aws s3 cp $TMP_DIR/master.yaml s3://$BUCKET_NAME/proxysql-deploy/master.yaml --region $REGION

# 更新CloudFormation堆栈
echo "更新CloudFormation堆栈: $STACK_NAME..."
aws cloudformation update-stack \
  --stack-name $STACK_NAME \
  --template-url https://s3.amazonaws.com/$BUCKET_NAME/proxysql-deploy/master.yaml \
  --parameters \
    ParameterKey=KeyName,ParameterValue=$KEY_NAME \
    ParameterKey=AllowedCidrIngress,ParameterValue=$ALLOWED_CIDR \
  --capabilities CAPABILITY_IAM \
  --region $REGION

# 等待堆栈更新完成
echo "等待堆栈更新完成..."
aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION

# 获取堆栈输出
echo "获取堆栈输出..."
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs" --output table

# 清理临时目录
echo "清理临时目录..."
rm -rf $TMP_DIR

echo "更新完成！"
