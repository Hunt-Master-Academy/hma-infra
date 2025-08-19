-- Tracking & recovery schema (stub)
CREATE TABLE IF NOT EXISTS pillars.tracking_recovery (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  method TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
