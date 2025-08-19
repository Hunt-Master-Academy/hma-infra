-- Migration V001: initial schema
BEGIN;
  -- Ensure extensions
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  CREATE EXTENSION IF NOT EXISTS citext;

  -- Create base schemas
  CREATE SCHEMA IF NOT EXISTS auth;
  CREATE SCHEMA IF NOT EXISTS users;
  CREATE SCHEMA IF NOT EXISTS content;
  CREATE SCHEMA IF NOT EXISTS progress;
  CREATE SCHEMA IF NOT EXISTS pillars;
  CREATE SCHEMA IF NOT EXISTS ml;
  CREATE SCHEMA IF NOT EXISTS analytics;
COMMIT;

-- mark migration as applied
INSERT INTO infra.schema_migrations(version)
VALUES ('V001__initial_schema.sql')
ON CONFLICT (version) DO NOTHING;
