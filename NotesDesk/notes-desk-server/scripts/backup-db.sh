#!/usr/bin/env bash
# 备份 SQLite 到 /data/backup/，保留最近 7 份
# 群晖：计划任务每日执行
#   docker exec notesdesk sh -c '/app/scripts/backup-db.sh'  # 若脚本在镜像内
# 或 NAS 上直接复制 data/store/notesdesk.db

set -euo pipefail

DATA_DIR="${DATA_DIR:-/data}"
DB="${DATA_DIR}/store/notesdesk.db"
BACKUP_DIR="${DATA_DIR}/backup"
KEEP=7

if [[ ! -f "$DB" ]]; then
  echo "database not found: $DB"
  exit 0
fi

mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d)
DEST="${BACKUP_DIR}/notesdesk-${STAMP}.db"

cp "$DB" "$DEST"
echo "backup: $DEST"

ls -1t "${BACKUP_DIR}"/notesdesk-*.db 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f
