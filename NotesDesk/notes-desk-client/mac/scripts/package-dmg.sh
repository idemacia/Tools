#!/usr/bin/env bash
# 构建 NotesDeskClient.app 并打包为 DMG
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="NotesDeskClient"
DISPLAY_NAME="NotesDesk Client"
VERSION="0.1.0"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/${APP_NAME}-${VERSION}.dmg"
ICON_SRC="${ICON_SRC:-$ROOT/Packaging/icon.png}"
IM_ICON="$ROOT/../../notes-desk-im/Packaging/icon.png"

echo "==> 1/5 准备图标..."
TARGET_ICON="$ROOT/Packaging/icon.png"
need_icons=0
if [[ ! -f "$ROOT/Packaging/AppIcon.icns" ]]; then
  need_icons=1
elif [[ -f "$TARGET_ICON" && "$TARGET_ICON" -nt "$ROOT/Packaging/AppIcon.icns" ]]; then
  need_icons=1
fi
if [[ "$need_icons" -eq 1 ]]; then
  if [[ -n "${ICON_SRC:-}" && -f "$ICON_SRC" ]]; then
    SRC_REAL="$(cd "$(dirname "$ICON_SRC")" && pwd)/$(basename "$ICON_SRC")"
    DST_REAL="$(cd "$(dirname "$TARGET_ICON")" && pwd)/$(basename "$TARGET_ICON")"
    if [[ "$SRC_REAL" != "$DST_REAL" ]]; then
      cp "$ICON_SRC" "$TARGET_ICON"
    fi
  elif [[ ! -f "$TARGET_ICON" && -f "$IM_ICON" ]]; then
    cp "$IM_ICON" "$TARGET_ICON"
  fi
  if [[ ! -f "$TARGET_ICON" ]]; then
    echo "未找到图标：请放置 $TARGET_ICON" >&2
    exit 1
  fi
  "$ROOT/scripts/build-icons.sh" "$TARGET_ICON"
fi

echo "==> 2/5 编译 Release..."
swift build -c release

BIN="$ROOT/.build/release/NotesDeskClient"
if [[ ! -x "$BIN" ]]; then
  echo "编译失败：未找到 $BIN" >&2
  exit 1
fi

echo "==> 3/5 组装 $APP_NAME.app ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Resources/安装说明.txt" <<'EOF'
NotesDesk Client 安装说明
=========================

1. 将 NotesDeskClient.app 拖入「应用程序」文件夹
2. 首次打开：系统设置 → 隐私与安全性 → 仍要打开（未签名时）
3. 从启动台或 Spotlight 打开 NotesDesk Client
   菜单栏出现 cloud 图标；浮窗会自动弹出

4. 在「设置」中填写：
   - 服务器地址：如 http://192.168.1.100:17887
   - Web 用户名/密码：默认 admin / admin
   - 或填写与 Docker 一致的 API Token

前置条件：
- NAS 已运行 notes-desk-server
- 浏览器可访问 http://<NAS_IP>:17887/health

注意：
- 本 App 是菜单栏应用，Dock 里没有图标，请看屏幕右上角菜单栏
- 仅填服务器地址会出现 HTTP 401，需登录或 Token
EOF

echo "==> 4/5 代码签名（adhoc，本地安装）..."
codesign --force --deep --sign - "$APP" 2>/dev/null || {
  echo "警告: codesign 失败，仍可尝试打开 App，或在系统设置中允许"
}

echo "==> 5/5 制作 DMG..."
STAGING="$DIST/dmg-staging"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -sf /Applications "$STAGING/Applications"
cp "$APP/Contents/Resources/安装说明.txt" "$STAGING/"

hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGING"

echo ""
echo "  App:  $APP"
echo "  DMG:  $DMG"
echo "  大小: $(du -sh "$DMG" | cut -f1)"
echo ""
echo "安装：打开 DMG → 拖入 Applications → 设置中填写 NAS 地址与登录信息"
