#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Building NotesDesk..."
swift build -c release

BIN="$ROOT/.build/release/NotesDesk"
if [[ ! -x "$BIN" ]]; then
  echo "Build failed: binary not found at $BIN" >&2
  exit 1
fi

echo "Starting NotesDesk..."
exec "$BIN"
