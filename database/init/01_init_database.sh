#!/usr/bin/env bash
set -euo pipefail

echo "Starting Hunt Master Academy Database Initialization..."

# Create required extensions and schemas
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'EOSQL'
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
    CREATE EXTENSION IF NOT EXISTS "btree_gin";
    CREATE EXTENSION IF NOT EXISTS "btree_gist";
    CREATE EXTENSION IF NOT EXISTS "postgis";
    CREATE EXTENSION IF NOT EXISTS "postgis_topology";
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE SCHEMA IF NOT EXISTS users;
    CREATE SCHEMA IF NOT EXISTS content;
    CREATE SCHEMA IF NOT EXISTS progress;
    CREATE SCHEMA IF NOT EXISTS game_calls;
    CREATE SCHEMA IF NOT EXISTS hunt_strategy;
    CREATE SCHEMA IF NOT EXISTS stealth_scouting;
    CREATE SCHEMA IF NOT EXISTS tracking_recovery;
    CREATE SCHEMA IF NOT EXISTS gear_marksmanship;
    CREATE SCHEMA IF NOT EXISTS ml_infrastructure;
    CREATE SCHEMA IF NOT EXISTS analytics;
    CREATE SCHEMA IF NOT EXISTS events;

    -- Schemas created above; role creation handled below via shell/psql
EOSQL

# Create roles/users idempotently via psql checks (avoid DO $$ shell expansion issues)
APP_PASSWORD_VALUE=${APP_PASSWORD:-app_password}

# analytics_reader role
if ! psql -v ON_ERROR_STOP=1 -tAc "SELECT 1 FROM pg_roles WHERE rolname='analytics_reader'" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" | grep -q 1; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE ROLE analytics_reader;"
fi
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "GRANT USAGE ON SCHEMA analytics TO analytics_reader;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO analytics_reader;"

# hma_app user
if ! psql -v ON_ERROR_STOP=1 -tAc "SELECT 1 FROM pg_roles WHERE rolname='hma_app'" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" | grep -q 1; then
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE USER hma_app WITH PASSWORD '${APP_PASSWORD_VALUE}';"
fi
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "GRANT CONNECT ON DATABASE \"$POSTGRES_DB\" TO hma_app;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "GRANT USAGE ON SCHEMA public TO hma_app;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO hma_app;"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO hma_app;"

echo "Database initialization complete!"
