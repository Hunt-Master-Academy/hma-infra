#!/usr/bin/env bash
set -euo pipefail

COMPOSE="docker compose -f docker/docker-compose.yml"
DB_USER=${POSTGRES_USER:-hma_admin}
DB_NAME=${POSTGRES_DB:-huntmaster}

$COMPOSE exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
SELECT now() as ts;
SELECT * FROM pg_stat_database WHERE datname = current_database();
SELECT schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch
FROM pg_stat_user_tables ORDER BY (idx_scan+seq_scan) DESC LIMIT 20;
SQL
