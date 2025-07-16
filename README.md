# ProxySQL 与 Aurora MySQL 读写分离部署

本项目提供了一套CloudFormation模板和脚本，用于部署Amazon Aurora MySQL集群和ProxySQL中间件，实现读写分离功能。

## 架构概述

该架构包含以下组件：

1. **VPC和子网**：包含公有子网和私有子网
2. **Aurora MySQL集群**：一个主实例和两个只读副本
3. **ProxySQL EC2实例**：部署在公有子网中的ProxySQL中间件

ProxySQL将根据SQL查询类型自动路由请求：
- 写入操作（INSERT, UPDATE, DELETE等）路由到Aurora主实例
- 读取操作（SELECT）路由到Aurora只读副本
- 特殊的SELECT FOR UPDATE查询路由到Aurora主实例

## 文件说明

- `network.yaml` - 创建VPC、子网和相关网络组件的CloudFormation模板
- `aurora-cluster.yaml` - 创建Aurora MySQL集群的CloudFormation模板
- `proxysql-ec2.yaml` - 创建ProxySQL EC2实例的CloudFormation模板
- `master.yaml` - 主CloudFormation模板，整合上述所有模板
- `deploy.sh` - 一键部署整个架构的脚本
- `update.sh` - 更新现有堆栈的脚本
- `deploy-aurora.sh` - 单独部署Aurora集群的脚本
- `deploy-proxysql.sh` - 单独部署ProxySQL的脚本
- `connect-proxysql.sh` - 连接到ProxySQL实例的脚本
- `test-rw-separation.sh` - 测试ProxySQL读写分离功能的脚本
- `verify-write-routing.sh` - 验证写入操作路由的脚本
- `performance-test.sh` - 性能测试脚本

## 部署步骤

### 方法1：一键部署整个架构

1. 修改`deploy.sh`中的参数，或者通过命令行参数提供：
   ```
   ./deploy.sh <S3存储桶名称> <堆栈名称> <AWS区域> [密钥对名称] [允许的CIDR]
   ```

2. 执行部署脚本：
   ```
   chmod +x deploy.sh
   ./deploy.sh my-bucket proxysql-stack us-east-1 my-key-pair 1.2.3.4/32
   ```

### 方法2：分步部署

1. 部署网络和Aurora集群：
   ```
   chmod +x deploy-aurora.sh
   ./deploy-aurora.sh my-bucket aurora-stack us-east-1 vpc-12345678 subnet-1234,subnet-5678
   ```

2. 部署ProxySQL：
   ```
   chmod +x deploy-proxysql.sh
   ./deploy-proxysql.sh my-bucket proxysql-stack us-east-1 vpc-12345678 subnet-1234 my-key-pair aurora-endpoint.rds.amazonaws.com aurora-reader.rds.amazonaws.com
   ```

## 测试读写分离功能

1. 连接到ProxySQL实例：
   ```
   chmod +x connect-proxysql.sh
   ./connect-proxysql.sh 12.34.56.78 /path/to/key.pem
   ```

2. 测试读写分离功能：
   ```
   chmod +x test-rw-separation.sh
   ./test-rw-separation.sh 12.34.56.78 /path/to/key.pem
   ```

3. 验证写入操作路由：
   ```
   chmod +x verify-write-routing.sh
   ./verify-write-routing.sh 12.34.56.78 /path/to/key.pem
   ```

4. 执行性能测试：
   ```
   chmod +x performance-test.sh
   ./performance-test.sh 12.34.56.78 /path/to/key.pem
   ```

## 连接信息

- **ProxySQL MySQL端点**：`<ProxySQL公网DNS>:6033`
- **ProxySQL管理端点**：`<ProxySQL公网DNS>:6032`
- **用户名**：`proxysqluser`
- **密码**：`pr0xySQL01Cred`（建议在生产环境中更改）

## 注意事项

1. 在生产环境中，建议限制允许访问ProxySQL的IP地址范围
2. 修改默认的数据库凭据
3. 根据实际负载调整Aurora和ProxySQL的实例类型
4. 考虑使用AWS Secrets Manager管理数据库凭据

## 故障排除

如果遇到问题，请检查：

1. EC2实例上的CloudWatch日志
2. ProxySQL日志：`/var/log/proxysql.log`
3. ProxySQL统计信息：连接到管理端口（6032）并查询相关表
4. Aurora数据库日志和性能洞察
