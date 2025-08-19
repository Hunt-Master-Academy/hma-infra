#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
COMPOSE="docker compose -f $ROOT_DIR/docker/docker-compose.yml"

if [[ ${1:-} == "--test-users" ]]; then
  file="$ROOT_DIR/database/seeds/02_test_users.sql"
  echo "[seed] applying $(basename "$file")";
  cat "$file" | $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-hma_admin}" -d "${POSTGRES_DB:-huntmaster}"
  exit 0
fi

if [[ $# -ge 1 ]]; then
  file="$1"
  echo "[seed] applying $(basename "$file")";
  cat "$file" | $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-hma_admin}" -d "${POSTGRES_DB:-huntmaster}"
  exit 0
fi

for f in $(ls -1 "$ROOT_DIR"/database/seeds/*.sql 2>/dev/null | sort); do
  echo "[seed] applying $(basename "$f")";
  cat "$f" | $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-hma_admin}" -d "${POSTGRES_DB:-huntmaster}";
done
