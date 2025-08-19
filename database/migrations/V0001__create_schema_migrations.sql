-- V0001: Migration tracking table
CREATE SCHEMA IF NOT EXISTS infra;

CREATE TABLE IF NOT EXISTS infra.schema_migrations (
  id SERIAL PRIMARY KEY,
  version TEXT NOT NULL UNIQUE,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Mark this migration as applied when run via migrate.sh
INSERT INTO infra.schema_migrations(version)
VALUES ('V0001__create_schema_migrations.sql')
ON CONFLICT (version) DO NOTHING;
