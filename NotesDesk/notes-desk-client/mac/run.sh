#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Building NotesDeskClient..."
swift build -c release

BIN="$ROOT/.build/release/NotesDeskClient"
if [[ ! -x "$BIN" ]]; then
  echo "Build failed: binary not found at $BIN" >&2
  exit 1
fi

echo "Starting NotesDeskClient (NAS API mode)..."
exec "$BIN"
