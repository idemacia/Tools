#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "未找到 xcodegen。请先安装：brew install xcodegen" >&2
  exit 1
fi

# 首次安装 Xcode 组件（修复 CoreSimulator 缺失）
if [[ ! -f /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator ]]; then
  echo "正在初始化 Xcode 组件（xcodebuild -runFirstLaunch）..."
  xcodebuild -runFirstLaunch
fi

xcodegen generate

SIGNING_COUNT=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Apple Development" || true)

if [[ "$SIGNING_COUNT" -eq 0 ]]; then
  echo ""
  echo "=========================================="
  echo "  未找到 Apple Development 签名证书"
  echo "=========================================="
  echo ""
  echo "Widget 扩展（含 App Group）必须签名，无法仅用命令行 ad-hoc 构建。"
  echo ""
  echo "请按以下步骤操作："
  echo "  1. 打开 Xcode → Settings → Accounts"
  echo "  2. 点击 + 登录你的 Apple ID（免费即可）"
  echo "  3. 打开工程："
  echo "       open NotesDeskWidget.xcodeproj"
  echo "  4. 选中 Targets「NotesDeskWidget」和「NotesDeskWidgetExtension」"
  echo "  5. Signing & Capabilities → 勾选 Automatically manage signing"
  echo "  6. 两个 Target 都添加 App Groups：group.com.notesdesk.widget"
  echo "  7. 点击 Run（⌘R）安装 Host + Widget"
  echo ""
  open NotesDeskWidget.xcodeproj 2>/dev/null || true
  exit 1
fi

echo "Building NotesDeskWidget..."
xcodebuild \
  -project NotesDeskWidget.xcodeproj \
  -scheme NotesDeskWidget \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -allowProvisioningUpdates \
  build

echo ""
echo "Build complete."
echo ""
echo "请用 Xcode 按 ⌘R 运行（推荐），或执行："
echo "  open \"\$(find ~/Library/Developer/Xcode/DerivedData/NotesDeskWidget-*/Build/Products/Debug -name NotesDeskWidget.app -maxdepth 1 2>/dev/null | head -1)\""
echo ""
echo "⚠  不要打开 DerivedData/.../Index.noindex/ 下的 .app（无可执行文件，会报「无法打开」）。"
echo "Run Host only (no Widget sync): ./run-host.sh"
