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

## 部署方式

本项目提供两种部署方式：

### 1. 一键部署（推荐）

使用主 CloudFormation 模板一次性部署整个架构，包括网络、Aurora 集群和 ProxySQL。

```bash
./deploy.sh <S3存储桶名称> <堆栈名称> <AWS区域> [密钥对名称] [允许的CIDR]
```

### 2. 分步部署

分别部署网络、Aurora 集群和 ProxySQL，适合需要更精细控制的场景。

```bash
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

## 前提条件

- AWS CLI 已安装并配置
- 有权限创建 CloudFormation 堆栈、VPC、EC2 实例和 RDS 数据库
- 一个 S3 存储桶用于存储 CloudFormation 模板
- 一个 EC2 密钥对用于 SSH 连接

## 注意事项

1. 在生产环境中，建议限制允许访问 ProxySQL 的 IP 地址范围
2. 修改默认的数据库凭据
3. 根据实际负载调整 Aurora 和 ProxySQL 的实例类型
4. 考虑使用 AWS Secrets Manager 管理数据库凭据

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 贡献

欢迎提交 Pull Request 和 Issue！
