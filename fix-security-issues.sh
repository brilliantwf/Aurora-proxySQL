#!/bin/bash

# 安全修复脚本 - 移除硬编码密码和敏感信息

echo "开始修复安全隐患..."

# 1. 替换硬编码的数据库密码
echo "替换硬编码的数据库密码..."
find . -type f -name "*.yaml" -exec sed -i '' 's/Default: pr0xySQL01Cred/Default: {{YOUR_DB_PASSWORD}}/g' {} \;
find . -type f -name "*.sh" -exec sed -i '' 's/DB_PASSWORD="{{YOUR_DB_PASSWORD}}"/DB_PASSWORD="{{YOUR_DB_PASSWORD}}"/g' {} \;
find . -type f -name "*.sh" -exec sed -i '' 's/-p{{YOUR_DB_PASSWORD}}/-p{{YOUR_DB_PASSWORD}}/g' {} \;
find . -type f -name "*.md" -exec sed -i '' 's/-p{{YOUR_DB_PASSWORD}}/-p{{YOUR_DB_PASSWORD}}/g' {} \;

# 2. 替换特定的数据库端点
echo "替换特定的数据库端点..."
find . -type f -name "*.sh" -exec sed -i '' 's/{{YOUR_AURORA_CLUSTER_ENDPOINT}}/{{YOUR_AURORA_CLUSTER_ENDPOINT}}/g' {} \;
find . -type f -name "*.sh" -exec sed -i '' 's/{{YOUR_AURORA_READER_ENDPOINT}}/{{YOUR_AURORA_READER_ENDPOINT}}/g' {} \;

# 3. 更新 CloudFormation 模板中的密码处理
echo "更新 CloudFormation 模板中的密码处理..."
find . -type f -name "*.yaml" -exec sed -i '' '/DBPassword:/,/Default:/s/Default:/NoEcho: true\n    Default:/g' {} \;

# 4. 添加安全提示到 README.md
echo "添加安全提示到 README.md..."
cat << 'EOF' > security_note.tmp
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

EOF

# 在 README.md 的"注意事项"部分之前插入安全提示
sed -i '' '/^## 注意事项/e cat security_note.tmp' README.md
rm security_note.tmp

echo "安全修复完成！"
echo "请注意：您需要用实际值替换所有 {{YOUR_DB_PASSWORD}}, {{YOUR_AURORA_CLUSTER_ENDPOINT}} 和 {{YOUR_AURORA_READER_ENDPOINT}} 占位符。"
