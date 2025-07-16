# 将项目推送到 GitHub 的步骤

按照以下步骤将此项目推送到 GitHub：

## 1. 在 GitHub 上创建新仓库

1. 登录到您的 GitHub 账户
2. 点击右上角的 "+" 图标，选择 "New repository"
3. 填写仓库名称，例如 "aurora-proxysql-deploy"
4. 添加描述：例如 "Aurora MySQL and ProxySQL deployment templates and scripts for read-write separation"
5. 选择仓库可见性（公开或私有）
6. 不要初始化仓库（不要添加 README、.gitignore 或 license）
7. 点击 "Create repository"

## 2. 将本地仓库推送到 GitHub

在终端中执行以下命令，将本地仓库推送到 GitHub（替换 YOUR_USERNAME 为您的 GitHub 用户名）：

```bash
cd /Users/fiwa/q/github/aurora-proxysql-deploy
git remote add origin https://github.com/YOUR_USERNAME/aurora-proxysql-deploy.git
git branch -M main
git push -u origin main
```

如果您使用 SSH 而不是 HTTPS，请使用以下命令：

```bash
cd /Users/fiwa/q/github/aurora-proxysql-deploy
git remote add origin git@github.com:YOUR_USERNAME/aurora-proxysql-deploy.git
git branch -M main
git push -u origin main
```

## 3. 验证推送是否成功

1. 访问您的 GitHub 仓库页面：https://github.com/YOUR_USERNAME/aurora-proxysql-deploy
2. 确认所有文件都已成功推送

## 4. 后续更新

对项目进行更改后，使用以下命令推送更新：

```bash
git add .
git commit -m "您的提交消息"
git push
```
