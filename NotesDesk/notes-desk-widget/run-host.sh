#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Building NotesWidgetHost (SPM)..."
swift build -c release

BIN="$ROOT/.build/release/NotesWidgetHost"
if [[ ! -x "$BIN" ]]; then
  echo "Build failed." >&2
  exit 1
fi

echo "Starting NotesWidgetHost..."
echo ""
echo "⚠  注意：SPM 直接运行的 Host 不含 App Group 签名，Widget 无法读取同步数据。"
echo "   调试 Widget 请用 Xcode 打开 NotesDeskWidget.xcodeproj 并按 ⌘R 运行。"
echo ""
exec "$BIN"
