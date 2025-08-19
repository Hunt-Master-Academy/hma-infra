-- Seed test users (stub)
INSERT INTO auth.users(email, username, password_hash, birth_date, email_verified, status)
VALUES ('test@example.com', 'tester', crypt('password', gen_salt('bf')), '1990-01-01', false, 'pending_verification')
ON CONFLICT (email) DO NOTHING;

-- Dev seed: test users with adult birth dates
TRUNCATE TABLE auth.sessions RESTART IDENTITY;

INSERT INTO auth.users (email, email_verified, username, password_hash, birth_date, status)
VALUES
  ('adult1@example.com', true, 'adult1', crypt('Password!1', gen_salt('bf')), '1989-01-01', 'active'),
  ('adult2@example.com', false, 'adult2', crypt('Password!2', gen_salt('bf')), '1990-05-12', 'pending_verification')
ON CONFLICT (email) DO NOTHING;
