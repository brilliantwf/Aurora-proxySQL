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

# 连接到ProxySQL实例
echo "正在连接到ProxySQL实例..."
ssh -i "$KEY_PATH" ec2-user@$PROXYSQL_PUBLIC_IP
