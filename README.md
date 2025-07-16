# Aurora MySQL 与 ProxySQL 读写分离部署

![Aurora ProxySQL Architecture](https://raw.githubusercontent.com/aws-samples/amazon-aurora-mysql-with-proxysql/main/architecture.png)

## 项目概述

本项目提供了一套完整的 CloudFormation 模板和脚本，用于在 AWS 上部署 Amazon Aurora MySQL 集群和 ProxySQL 中间件，实现自动读写分离功能。通过这种架构，您可以：

1. **优化数据库性能**：将读取操作分散到 Aurora 只读副本，减轻主实例负担
2. **简化应用程序开发**：应用程序只需连接到单一 ProxySQL 端点，无需处理读写分离逻辑
3. **提高系统可用性**：当数据库实例发生故障时，ProxySQL 可以自动将流量路由到可用的实例
4. **灵活配置查询路由规则**：根据 SQL 查询类型自动路由请求

## 架构特点

- **Aurora MySQL 8.0**：使用最新的 Aurora MySQL 版本 3（8.0.mysql_aurora.3.09.0）
- **ProxySQL 2.5.x**：兼容 MySQL 8.0 的最新 ProxySQL 版本
- **灵活部署选项**：支持一键部署整个架构或分步部署各个组件
- **自动读写分离**：基于 SQL 查询类型自动路由请求
- **详细的测试脚本**：提供多种测试脚本验证读写分离功能和性能

## 部署准备

在开始部署之前，请确保完成以下准备工作，以避免部署过程中出现异常：

1. **替换占位符**：
   - 在所有脚本和模板中，将 `{{YOUR_DB_PASSWORD}}` 替换为您的实际数据库密码
   - 密码应符合 Aurora 要求：至少8个字符，包含大小写字母、数字和特殊字符

2. **检查脚本权限**：
   - 确保所有 `.sh` 脚本具有执行权限：`chmod +x *.sh`

3. **S3 存储桶准备**：
   - 确保您指定的 S3 存储桶已存在且您有权限访问
   - 存储桶应与您部署的区域在同一区域，或启用跨区域访问

4. **EC2 密钥对**：
   - 确保您指定的 EC2 密钥对在目标区域中存在
   - 保存好密钥对的私钥文件（.pem），后续连接 ProxySQL 实例时需要使用

5. **网络配置**：
   - 如果使用现有 VPC，确保它至少有两个不同可用区的子网
   - 确保 CIDR 范围不与现有网络冲突

6. **IAM 权限**：
   - 确保您的 AWS 账户有足够权限创建所需资源（VPC、EC2、RDS 等）
   - 如果使用 IAM 角色，确保角色有 CloudFormation、S3、EC2、RDS 等服务的权限

## 部署方式

本项目提供两种部署方式：

### 1. 一键部署（推荐）

使用主 CloudFormation 模板一次性部署整个架构，包括网络、Aurora 集群和 ProxySQL。

```bash
# 首先替换脚本中的占位符
sed -i 's/{{YOUR_DB_PASSWORD}}/您的实际密码/g' deploy.sh master.yaml aurora-cluster.yaml proxysql-ec2.yaml

# 然后执行部署
./deploy.sh <S3存储桶名称> <堆栈名称> <AWS区域> [密钥对名称] [允许的CIDR]
```

### 2. 分步部署

分别部署网络、Aurora 集群和 ProxySQL，适合需要更精细控制的场景。

```bash
# 首先替换脚本中的占位符
sed -i 's/{{YOUR_DB_PASSWORD}}/您的实际密码/g' deploy-aurora.sh deploy-proxysql.sh aurora-cluster.yaml proxysql-ec2.yaml

# 部署 Aurora 集群
./deploy-aurora.sh <S3存储桶名称> <堆栈名称> <AWS区域> <VPC ID> <子网ID列表>

# 部署 ProxySQL
./deploy-proxysql.sh <S3存储桶名称> <堆栈名称> <AWS区域> <VPC ID> <子网ID> <密钥对名称> <Aurora集群端点> <Aurora读取端点>
```

## 测试读写分离功能

部署完成后，可以使用提供的测试脚本验证读写分离功能：

```bash
# 测试读写分离功能
./test-rw-separation.sh <ProxySQL公网IP> <SSH密钥路径>

# 验证写入操作路由
./verify-write-routing.sh <ProxySQL公网IP> <SSH密钥路径>

# 执行性能测试
./performance-test.sh <ProxySQL公网IP> <SSH密钥路径>
```

### 测试注意事项

1. **确保SSH密钥权限正确**：
   - 密钥文件权限应设置为 `400` 或 `600`：`chmod 400 your-key.pem`
   - 否则SSH连接可能会被拒绝

2. **等待服务完全启动**：
   - ProxySQL 和 Aurora 集群可能需要几分钟才能完全初始化
   - 如果测试失败，请等待几分钟后重试

3. **检查安全组设置**：
   - 确保您的 IP 地址在允许访问 ProxySQL 的 CIDR 范围内
   - 验证 ProxySQL 安全组允许从您的 IP 访问 22 端口(SSH)和 6033 端口(MySQL)

4. **测试脚本中的端点**：
   - 如果您修改了测试脚本中的 Aurora 端点占位符，请确保使用正确的实际端点替换

## 文件说明

- **CloudFormation 模板**：
  - `network.yaml` - 创建 VPC 和子网
  - `aurora-cluster.yaml` - 创建 Aurora MySQL 集群
  - `proxysql-ec2.yaml` - 创建 ProxySQL EC2 实例
  - `master.yaml` - 主模板，整合上述所有模板

- **部署脚本**：
  - `deploy.sh` - 一键部署整个架构
  - `update.sh` - 更新现有堆栈
  - `deploy-aurora.sh` - 单独部署 Aurora 集群
  - `deploy-proxysql.sh` - 单独部署 ProxySQL

- **测试脚本**：
  - `connect-proxysql.sh` - 连接到 ProxySQL 实例
  - `test-rw-separation.sh` - 测试读写分离功能
  - `verify-write-routing.sh` - 验证写入操作路由
  - `performance-test.sh` - 性能测试

## 详细文档

- [安装指南](INSTALL.md) - 详细的安装步骤和说明
- [目录结构](STRUCTURE.md) - 项目文件和目录结构说明
- [ProxySQL架构](PROXYSQL_ARCHITECTURE.md) - ProxySQL工作原理与架构详解
- [连接池配置](CONNECTION_POOL.md) - ProxySQL连接池增强版说明

## 前提条件

- AWS CLI 已安装并配置
- 有权限创建 CloudFormation 堆栈、VPC、EC2 实例和 RDS 数据库
- 一个 S3 存储桶用于存储 CloudFormation 模板
- 一个 EC2 密钥对用于 SSH 连接

## 安全注意事项

1. **避免使用硬编码密码**：
   - 部署前请修改所有脚本和模板中的 `{{YOUR_DB_PASSWORD}}` 占位符
   - 生产环境中建议使用 AWS Secrets Manager 或参数存储管理敏感凭据

2. **限制访问范围**：
   - 确保 `AllowedCidrIngress` 参数设置为最小必要的 IP 范围
   - 考虑使用 VPN 或 AWS Direct Connect 进行私有访问

3. **定期轮换凭据**：
   - 实施定期密码轮换策略
   - 使用 AWS Secrets Manager 自动轮换功能

4. **监控和审计**：
   - 启用 CloudTrail 和 RDS 审计日志
   - 设置 CloudWatch 警报监控异常访问模式

## 注意事项

1. 在生产环境中，建议限制允许访问 ProxySQL 的 IP 地址范围
2. 修改默认的数据库凭据
3. 根据实际负载调整 Aurora 和 ProxySQL 的实例类型
4. 考虑使用 AWS Secrets Manager 管理数据库凭据

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 贡献

欢迎提交 Pull Request 和 Issue！
