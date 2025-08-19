-- Game calls pillar schema (stub)
CREATE SCHEMA IF NOT EXISTS pillars;

CREATE TABLE IF NOT EXISTS pillars.game_calls (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  species TEXT,
  difficulty INT CHECK (difficulty BETWEEN 1 AND 5),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
