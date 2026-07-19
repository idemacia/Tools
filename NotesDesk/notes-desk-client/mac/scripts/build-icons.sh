#!/usr/bin/env bash
# 从 PNG 生成 macOS AppIcon.icns
# 用法：./scripts/build-icons.sh [源图路径，默认 Packaging/icon.png]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGING="$ROOT/Packaging"

if [[ -n "${1:-}" ]]; then
  SRC="$1"
elif [[ -f "$PACKAGING/icon.png" ]]; then
  SRC="$PACKAGING/icon.png"
else
  echo "未找到源图。请将 PNG 放到 $PACKAGING/icon.png" >&2
  exit 1
fi

ICONSET="$PACKAGING/AppIcon.iconset"
ICNS="$PACKAGING/AppIcon.icns"

echo "==> 源图: $SRC"
mkdir -p "$ICONSET"

sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

echo "==> 生成 AppIcon.icns"
iconutil -c icns "$ICONSET" -o "$ICNS"
echo "    $ICNS"
echo ""
echo "完成。接下来运行: ./scripts/package-dmg.sh"
