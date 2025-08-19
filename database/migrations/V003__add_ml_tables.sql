-- Migration V003: add ML tables (stub)
BEGIN;
  CREATE TABLE IF NOT EXISTS ml.model_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    artifact_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
COMMIT;

-- mark migration as applied
INSERT INTO infra.schema_migrations(version)
VALUES ('V003__add_ml_tables.sql')
ON CONFLICT (version) DO NOTHING;
