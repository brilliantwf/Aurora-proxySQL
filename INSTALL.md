# ProxySQL 与 Aurora MySQL 安装指南

本指南将帮助您部署 ProxySQL 和 Aurora MySQL 集群，并配置读写分离功能。

## 前提条件

1. AWS CLI 已安装并配置
2. 有权限创建 CloudFormation 堆栈、VPC、EC2 实例和 RDS 数据库
3. 一个 S3 存储桶用于存储 CloudFormation 模板
4. 一个 EC2 密钥对用于 SSH 连接

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/yourusername/amazon-aurora-proxysql-example.git
cd amazon-aurora-proxysql-example/proxysql-deploy
```

### 2. 一键部署（推荐）

修改 `deploy.sh` 中的参数或通过命令行提供：

```bash
./deploy.sh my-bucket proxysql-stack us-east-1 my-key-pair 1.2.3.4/32
```

参数说明：
- `my-bucket`: S3 存储桶名称
- `proxysql-stack`: CloudFormation 堆栈名称
- `us-east-1`: AWS 区域
- `my-key-pair`: EC2 密钥对名称
- `1.2.3.4/32`: 允许访问 ProxySQL 的 IP 地址范围（建议限制为您的 IP）

### 3. 分步部署（高级）

如果您想更精细地控制部署过程，可以分步部署：

1. 部署网络和 Aurora 集群：

```bash
./deploy-aurora.sh my-bucket aurora-stack us-east-1 vpc-12345678 subnet-1234,subnet-5678
```

2. 部署 ProxySQL：

```bash
./deploy-proxysql.sh my-bucket proxysql-stack us-east-1 vpc-12345678 subnet-1234 my-key-pair aurora-endpoint.rds.amazonaws.com aurora-reader.rds.amazonaws.com
```

## 验证部署

### 1. 连接到 ProxySQL 实例

```bash
./connect-proxysql.sh <ProxySQL公网IP> /path/to/key.pem
```

### 2. 测试读写分离功能

```bash
./test-rw-separation.sh <ProxySQL公网IP> /path/to/key.pem
```

### 3. 验证写入操作路由

```bash
./verify-write-routing.sh <ProxySQL公网IP> /path/to/key.pem
```

### 4. 执行性能测试

```bash
./performance-test.sh <ProxySQL公网IP> /path/to/key.pem
```

## 连接到数据库

### 通过 ProxySQL 连接（推荐）

```bash
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h <ProxySQL公网DNS> -P 6033
```

### 直接连接到 Aurora 主实例

```bash
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h <Aurora集群端点>
```

### 直接连接到 Aurora 读取副本

```bash
mysql -u proxysqluser -p{{YOUR_DB_PASSWORD}} -h <Aurora读取端点>
```

### 连接到 ProxySQL 管理界面

```bash
mysql -u admin -padmin -h <ProxySQL公网DNS> -P 6032
```

## 常用 ProxySQL 管理命令

### 查看 MySQL 服务器配置

```sql
SELECT * FROM mysql_servers;
```

### 查看 MySQL 查询规则

```sql
SELECT * FROM mysql_query_rules;
```

### 查看查询路由统计

```sql
SELECT hostgroup, digest_text, count_star 
FROM stats_mysql_query_digest 
ORDER BY count_star DESC;
```

### 查看连接池状态

```sql
SELECT * FROM stats_mysql_connection_pool;
```

## 清理资源

当您不再需要这些资源时，可以删除 CloudFormation 堆栈：

```bash
aws cloudformation delete-stack --stack-name proxysql-stack --region us-east-1
```

## 故障排除

如果遇到问题，请检查：

1. CloudFormation 堆栈事件
2. EC2 实例上的系统日志：`/var/log/cloud-init-output.log`
3. ProxySQL 日志：`/var/log/proxysql.log`
4. Aurora 数据库日志
