-- Migration V002: add compliance constructs (stub)
BEGIN;
  -- Example: audit table
  CREATE TABLE IF NOT EXISTS auth.audit_log (
    id BIGSERIAL PRIMARY KEY,
    actor UUID,
    action TEXT NOT NULL,
    target TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
COMMIT;

-- mark migration as applied
INSERT INTO infra.schema_migrations(version)
VALUES ('V002__add_compliance.sql')
ON CONFLICT (version) DO NOTHING;
