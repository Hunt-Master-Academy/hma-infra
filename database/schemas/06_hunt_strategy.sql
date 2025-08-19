-- Hunt strategy pillar schema (stub)
CREATE TABLE IF NOT EXISTS pillars.hunt_strategies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  terrain TEXT,
  season TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
