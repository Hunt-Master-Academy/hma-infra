-- Stealth & scouting schema (stub)
CREATE TABLE IF NOT EXISTS pillars.stealth_scouting (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  technique TEXT NOT NULL,
  environment TEXT,
  difficulty INT CHECK (difficulty BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
