#!/usr/bin/env bash
set -euo pipefail

COMPOSE="docker compose -f docker/docker-compose.yml"
DB_USER=${POSTGRES_USER:-hma_admin}
DB_NAME=${POSTGRES_DB:-huntmaster}

$COMPOSE exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
SELECT now() as ts;
SELECT pid, now()-query_start AS runtime, usename, query
FROM pg_stat_activity
WHERE state <> 'idle' AND now()-query_start > interval '1 second'
ORDER BY runtime DESC
LIMIT 20;
SQL
