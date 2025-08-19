-- Analytics aggregation functions (stub)
CREATE OR REPLACE FUNCTION analytics.fn_events_by_name(p_name TEXT)
RETURNS SETOF analytics.events AS $$
BEGIN
  RETURN QUERY SELECT * FROM analytics.events WHERE event_name = p_name;
END;
$$ LANGUAGE plpgsql STABLE;
