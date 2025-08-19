-- User-related functions (stub)
CREATE OR REPLACE FUNCTION auth.fn_user_exists(p_email CITEXT)
RETURNS BOOLEAN AS $$
DECLARE
  exists BOOLEAN;
BEGIN
  SELECT TRUE INTO exists FROM auth.users WHERE email = p_email LIMIT 1;
  RETURN COALESCE(exists, FALSE);
END;
$$ LANGUAGE plpgsql STABLE;
