#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$ROOT_DIR/docker"

BACKUP_DIR=${1:-"$ROOT_DIR/backups"}
mkdir -p "$BACKUP_DIR"
FILE="$BACKUP_DIR/pg_$(date +%Y%m%d_%H%M%S).sql.gz"

echo "[backup] Writing to $FILE"
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$FILE"

echo "[backup] Done."
