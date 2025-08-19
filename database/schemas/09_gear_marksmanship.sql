-- Gear & marksmanship schema (stub)
CREATE TABLE IF NOT EXISTS pillars.gear_marksmanship (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gear_item TEXT NOT NULL,
  skill_level INT CHECK (skill_level BETWEEN 1 AND 5),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
