#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_GROUP="group.com.notesdesk.widget"
CONTAINER="$HOME/Library/Group Containers/$APP_GROUP"

echo "=== NotesDesk Widget 调试检查 ==="
echo ""

# 1. 工具链
echo "[1/5] 工具链"
if command -v xcodegen >/dev/null 2>&1; then
  echo "  ✓ xcodegen: $(command -v xcodegen)"
else
  echo "  ✗ xcodegen 未安装 → brew install xcodegen"
fi
if xcodebuild -version >/dev/null 2>&1; then
  echo "  ✓ $(xcodebuild -version | head -1)"
else
  echo "  ✗ Xcode 未安装或未配置"
fi
echo ""

# 2. 签名（Widget 必需）
echo "[2/5] 代码签名"
SIGNING_COUNT=$(security find-identity -v -p codesigning 2>/dev/null | grep -c "Apple Development" || true)
if [[ "$SIGNING_COUNT" -gt 0 ]]; then
  echo "  ✓ 找到 $SIGNING_COUNT 个 Apple Development 证书"
  security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -3 | sed 's/^/    /'
else
  echo "  ✗ 未找到签名证书（Widget 无法构建）"
  echo "    → Xcode → Settings → Accounts → 登录 Apple ID"
  echo "    → 打开 NotesDeskWidget.xcodeproj → 两个 Target 勾选 Automatically manage signing"
fi
echo ""

# 3. Host 进程（只匹配实际 App，避免误报 Xcode 索引进程）
echo "[3/5] Host 进程"
HOST_PIDS=$(pgrep -f '/NotesDeskWidget\.app/Contents/MacOS/NotesDeskWidget' 2>/dev/null || true)
if [[ -n "$HOST_PIDS" ]]; then
  ps -p "$HOST_PIDS" -o pid=,command= 2>/dev/null | sed 's/^/    /'
  echo "  ✓ Host 正在运行"
else
  echo "  ✗ Host 未运行"
  if pgrep -lf 'NotesDeskWidget.*swift-frontend' >/dev/null 2>&1; then
    echo "    ℹ Xcode 正在索引/编译，尚未启动 App → 配置签名后按 ⌘R"
  fi
  echo "    → 请用 Xcode ⌘R 运行（推荐，含 App Group）"
  echo "    → 或 ./run-host.sh（仅测试读备忘录，无 App Group）"
fi
echo ""

# 4. App Group 容器
echo "[4/5] App Group 数据 ($APP_GROUP)"
if [[ -d "$CONTAINER" ]]; then
  echo "  ✓ 容器目录存在: $CONTAINER"
  PLIST="$CONTAINER/Library/Preferences/$APP_GROUP.plist"
  FOLDERS_JSON="$CONTAINER/folders.json"
  if [[ -f "$FOLDERS_JSON" ]]; then
    echo "  ✓ 已有文件夹列表: $FOLDERS_JSON"
    python3 -c "import json,sys; d=json.load(open('$FOLDERS_JSON')); print(f'    共 {len(d)} 个文件夹')" 2>/dev/null || true
  elif [[ -f "$PLIST" ]]; then
    echo "  ✓ 已有同步数据 (UserDefaults)"
  else
    echo "  ⚠ 容器存在但尚无文件夹数据"
    echo "    → Host 菜单栏点「重新加载文件夹列表」"
    echo "    → 若仍为空，检查 系统设置 → 自动化 → NotesDeskWidget → 备忘录"
  fi
  WIDGET_JSON="$CONTAINER/widget-current.json"
  if [[ -f "$WIDGET_JSON" ]]; then
    echo "  ✓ 当前快照: $WIDGET_JSON"
    python3 -c "import json; d=json.load(open('$WIDGET_JSON')); print('    标题:', d.get('note',{}).get('title','?'))" 2>/dev/null || true
  fi
else
  echo "  ✗ 容器不存在 → 需通过 Xcode 签名运行 Host（./run-host.sh 无法写入 App Group）"
fi
echo ""

# 5. Widget 扩展
echo "[5/5] Widget 扩展"
WIDGET_APP=$(mdfind "kMDItemCFBundleIdentifier == 'com.notesdesk.widget.host'" 2>/dev/null | head -1)
if [[ -n "$WIDGET_APP" ]]; then
  echo "  ✓ 已安装: $WIDGET_APP"
else
  echo "  ✗ 未找到已安装的 Host App → Xcode ⌘R 构建并运行"
fi
echo ""

# 6. localhost 快照服务
echo "[6/6] localhost 快照服务 (端口 19876)"
if curl -sf --max-time 2 http://127.0.0.1:19876/snapshot >/dev/null 2>&1; then
  echo "  ✓ Host 快照服务可访问"
  curl -sf --max-time 2 http://127.0.0.1:19876/snapshot | python3 -c "import json,sys; d=json.load(sys.stdin); print('    标题:', d.get('note',{}).get('title','?'))" 2>/dev/null || true
else
  echo "  ✗ 无法连接 localhost:19876"
  echo "    → 请 Xcode ⌘R 重新运行 Host（需最新构建含快照服务）"
  echo "    → 运行后菜单栏点「立即同步并刷新 Widget」"
fi
echo ""

echo "=== 推荐调试流程 ==="
echo "  1. open NotesDeskWidget.xcodeproj"
echo "  2. 两个 Target 配置 Signing + App Group: $APP_GROUP"
echo "  3. ⌘R 运行 Host"
echo "  4. 菜单栏选文件夹 → 立即同步并刷新 Widget"
echo "  5. 桌面 Control+点击 → 编辑小组件 → 添加 NotesDesk"
echo "  6. 修改备忘录，观察 Widget 是否更新"
echo ""
