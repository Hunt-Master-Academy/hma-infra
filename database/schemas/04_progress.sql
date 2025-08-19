-- Progress tracking schema (stub)
CREATE SCHEMA IF NOT EXISTS progress;

CREATE TABLE IF NOT EXISTS progress.user_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  content_id UUID NOT NULL REFERENCES content.items(id),
  status TEXT NOT NULL DEFAULT 'not_started',
  score NUMERIC,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
