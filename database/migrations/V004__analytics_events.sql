-- V004: Analytics events table
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.events (
  id BIGSERIAL PRIMARY KEY,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_name TEXT NOT NULL,
  payload JSONB
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_occurred_at ON analytics.events(occurred_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_name ON analytics.events(event_name);

-- mark migration as applied
INSERT INTO infra.schema_migrations(version)
VALUES ('V004__analytics_events.sql')
ON CONFLICT (version) DO NOTHING;
