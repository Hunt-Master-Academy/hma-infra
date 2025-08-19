#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
COMPOSE="docker compose -f $ROOT_DIR/docker/docker-compose.yml"

ok=0

# DB connectivity and basic query
if $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-hma_admin}" -d "${POSTGRES_DB:-huntmaster}" -c "SELECT 1;" >/dev/null; then
  echo "[smoke] DB SELECT 1 OK"; ok=$((ok+1)); else echo "[smoke] DB FAILED"; fi

# Redis ping
if $COMPOSE exec -T redis redis-cli -a "${REDIS_PASSWORD:-development_redis}" ping | grep -q PONG; then
  echo "[smoke] Redis PING OK"; ok=$((ok+1)); else echo "[smoke] Redis FAILED"; fi

# MinIO health
if curl -fsS http://localhost:9000/minio/health/live >/dev/null; then
  echo "[smoke] MinIO live OK"; ok=$((ok+1)); else echo "[smoke] MinIO FAILED"; fi

# ML server health with retries
ml_ok=0
for i in {1..15}; do
  if curl -fsS http://localhost:8010/ >/dev/null; then ml_ok=1; break; fi
  sleep 1
done
if [[ $ml_ok -eq 1 ]]; then echo "[smoke] ML server OK"; ok=$((ok+1)); else echo "[smoke] ML server FAILED"; fi

[[ $ok -ge 3 ]] || { echo "[smoke] Some checks failed"; exit 1; }

echo "[smoke] All basic checks passed ($ok)"
