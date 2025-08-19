-- Compliance audit logging triggers (stub)
CREATE OR REPLACE FUNCTION auth.fn_audit()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO auth.audit_log(actor, action, target, metadata)
  VALUES (NULL, TG_OP, TG_TABLE_NAME, row_to_json(NEW));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
