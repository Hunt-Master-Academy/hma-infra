-- Progress calculation functions (stub)
CREATE OR REPLACE FUNCTION progress.fn_completion_percentage(p_user UUID)
RETURNS NUMERIC AS $$
DECLARE
  total INT;
  completed INT;
BEGIN
  SELECT count(*) INTO total FROM progress.user_progress WHERE user_id = p_user;
  SELECT count(*) INTO completed FROM progress.user_progress WHERE user_id = p_user AND status = 'completed';
  IF total = 0 THEN RETURN 0; END IF;
  RETURN ROUND((completed::NUMERIC / total::NUMERIC) * 100, 2);
END;
$$ LANGUAGE plpgsql STABLE;
