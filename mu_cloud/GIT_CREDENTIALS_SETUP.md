# Git 凭据配置指南

## 当前状态

✅ Git 凭据助手已配置为使用 macOS 钥匙串（osxkeychain）

## 问题说明

在 Cursor 的非交互式环境中，Git 无法访问钥匙串或提示输入密码，因此会出现 "Device not configured" 错误。

## 解决方案

### 方案 1：在终端中手动输入一次密码（推荐）

在终端中执行以下命令，输入一次密码后，密码会被保存到钥匙串：

```bash
cd /path/to/mu_cloud
git fetch origin
```

输入密码后，密码会被保存到 macOS 钥匙串，之后在 Cursor 中执行 git 命令时应该可以自动使用。

### 方案 2：使用访问令牌（如果服务器支持）

如果您的 Git 服务器支持访问令牌（Access Token），可以：

1. 在服务器上生成访问令牌
2. 使用令牌代替密码：

```bash
git remote set-url origin https://USERNAME:YOUR_TOKEN@git.example.com/group/mu_cloud.git
```

### 方案 3：使用 SSH 密钥（如果服务器支持）

如果服务器支持 SSH，可以：

1. 确保 SSH 公钥已添加到服务器的 authorized_keys
2. 将远程 URL 改为 SSH：

```bash
git remote set-url origin git@git.example.com:group/mu_cloud.git
```

## 测试配置

配置完成后，可以在 Cursor 中测试：

```bash
git fetch origin
git status
```

如果仍然提示需要密码，请使用方案 1 在终端中手动执行一次。

## 注意事项

- macOS 钥匙串中的凭据可能会过期，需要定期更新
- 如果更改了密码，需要重新输入
- 在非交互式环境中，某些操作可能仍然无法访问钥匙串
