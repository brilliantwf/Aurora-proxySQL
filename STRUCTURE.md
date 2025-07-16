# 项目目录结构说明

本项目包含以下文件和目录：

```
proxysql-deploy/
├── README.md                  # 项目概述和使用说明
├── INSTALL.md                 # 详细安装指南
├── STRUCTURE.md               # 本文件，说明目录结构
├── network.yaml               # 网络基础设施CloudFormation模板
├── aurora-cluster.yaml        # Aurora集群CloudFormation模板
├── proxysql-ec2.yaml          # ProxySQL EC2实例CloudFormation模板
├── master.yaml                # 主CloudFormation模板
├── deploy.sh                  # 一键部署脚本
├── update.sh                  # 更新堆栈脚本
├── deploy-aurora.sh           # 单独部署Aurora集群脚本
├── deploy-proxysql.sh         # 单独部署ProxySQL脚本
├── connect-proxysql.sh        # 连接到ProxySQL实例脚本
├── test-rw-separation.sh      # 测试读写分离功能脚本
├── verify-write-routing.sh    # 验证写入操作路由脚本
└── performance-test.sh        # 性能测试脚本
```

## CloudFormation模板说明

### network.yaml

创建VPC、子网、路由表、互联网网关和NAT网关等网络基础设施。

主要资源：
- VPC
- 2个公有子网（不同可用区）
- 2个私有子网（不同可用区）
- 互联网网关
- NAT网关
- 路由表和路由

### aurora-cluster.yaml

创建Aurora MySQL集群，包括一个主实例和两个只读副本。

主要资源：
- Aurora DB集群
- Aurora DB实例（1个主实例，2个只读副本）
- 安全组
- 参数组
- 子网组
- 监控角色

### proxysql-ec2.yaml

创建ProxySQL EC2实例，并配置ProxySQL以实现读写分离。

主要资源：
- EC2实例
- 安全组
- IAM角色和实例配置文件
- 用户数据脚本（安装和配置ProxySQL）

### master.yaml

整合上述所有模板的主模板，提供一键部署功能。

## 脚本说明

### deploy.sh

一键部署整个架构的脚本，包括网络、Aurora集群和ProxySQL。

用法：
```
./deploy.sh <S3存储桶名称> <堆栈名称> <AWS区域> [密钥对名称] [允许的CIDR]
```

### update.sh

更新现有堆栈的脚本。

用法：
```
./update.sh <S3存储桶名称> <堆栈名称> <AWS区域> [密钥对名称] [允许的CIDR]
```

### deploy-aurora.sh

单独部署Aurora集群的脚本。

用法：
```
./deploy-aurora.sh <S3存储桶名称> <堆栈名称> <AWS区域> <VPC ID> <子网ID列表(逗号分隔)> [数据库名称] [用户名] [密码] [实例类型]
```

### deploy-proxysql.sh

单独部署ProxySQL的脚本。

用法：
```
./deploy-proxysql.sh <S3存储桶名称> <堆栈名称> <AWS区域> <VPC ID> <子网ID> <密钥对名称> <Aurora集群端点> <Aurora读取端点> [允许的CIDR] [数据库名称] [用户名] [密码] [实例类型]
```

### connect-proxysql.sh

连接到ProxySQL实例的脚本。

用法：
```
./connect-proxysql.sh <ProxySQL公网IP> <SSH密钥路径>
```

### test-rw-separation.sh

测试ProxySQL读写分离功能的脚本。

用法：
```
./test-rw-separation.sh <ProxySQL公网IP> <SSH密钥路径>
```

### verify-write-routing.sh

验证写入操作路由的脚本。

用法：
```
./verify-write-routing.sh <ProxySQL公网IP> <SSH密钥路径>
```

### performance-test.sh

性能测试脚本，模拟多个并发读写操作。

用法：
```
./performance-test.sh <ProxySQL公网IP> <SSH密钥路径>
```
