-- V0002: Auth core tables and constraints
CREATE SCHEMA IF NOT EXISTS auth;

-- users table
CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  birth_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'pending_verification',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- age gate: ensure >= 18 years
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE c.conname = 'users_age_18_check' AND n.nspname = 'auth' AND t.relname = 'users'
  ) THEN
    ALTER TABLE auth.users
      ADD CONSTRAINT users_age_18_check
      CHECK (birth_date <= (current_date - INTERVAL '18 years'));
  END IF;
END $$;

-- updated_at trigger
CREATE OR REPLACE FUNCTION auth.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON auth.users;
CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON auth.users
FOR EACH ROW EXECUTE FUNCTION auth.set_updated_at();

-- sessions table
CREATE TABLE IF NOT EXISTS auth.sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  refresh_token VARCHAR(255) NOT NULL UNIQUE,
  user_agent TEXT,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- legal acceptance table
CREATE TABLE IF NOT EXISTS auth.legal_acceptance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL,
  doc_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON auth.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON auth.users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON auth.users(username);

-- mark migration as applied
INSERT INTO infra.schema_migrations(version)
VALUES ('V0002__auth_core.sql')
ON CONFLICT (version) DO NOTHING;
