#!/bin/bash
# Git 凭据配置脚本
# 执行此脚本后，输入一次密码，密码会被保存到 macOS 钥匙串

echo "正在配置 Git 凭据..."
echo "请在弹出的对话框中输入您的密码"
echo ""

cd "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 尝试 fetch，这会触发密码输入
git fetch origin

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 凭据已成功保存到钥匙串！"
    echo "现在可以在 Cursor 中执行 git 命令了。"
else
    echo ""
    echo "❌ 凭据保存失败，请检查密码是否正确。"
fi
