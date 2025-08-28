-- Demo data for local development (idempotent)
-- Load with: ./scripts/seed.sh database/seeds/05_demo_data.sql

-- Users
INSERT INTO auth.users (email, email_verified, username, password_hash, birth_date, status)
VALUES 
  ('demo1@huntmaster.ai', TRUE, 'demo1', 'demo_hash', '2000-01-01', 'active')
ON CONFLICT (email) DO NOTHING;

INSERT INTO auth.users (email, email_verified, username, password_hash, birth_date, status)
VALUES 
  ('demo2@huntmaster.ai', FALSE, 'demo2', 'demo_hash', '2005-05-05', 'pending_verification')
ON CONFLICT (email) DO NOTHING;

-- Profiles
INSERT INTO users.profiles (user_id, display_name, avatar_url, bio)
SELECT u.id, 'Demo User 1', 'https://demo1.avatar', 'First demo user'
FROM auth.users u
WHERE u.username = 'demo1'
  AND NOT EXISTS (
    SELECT 1 FROM users.profiles p WHERE p.user_id = u.id
  );

INSERT INTO users.profiles (user_id, display_name, avatar_url, bio)
SELECT u.id, 'Demo User 2', 'https://demo2.avatar', 'Second demo user'
FROM auth.users u
WHERE u.username = 'demo2'
  AND NOT EXISTS (
    SELECT 1 FROM users.profiles p WHERE p.user_id = u.id
  );

-- Content
INSERT INTO content.items (title, body, content_type, created_by)
SELECT 'Welcome Guide', 'How to use Hunt Master Academy', 'guide', u.id
FROM auth.users u
WHERE u.username = 'demo1'
  AND NOT EXISTS (
    SELECT 1 FROM content.items c WHERE c.title = 'Welcome Guide'
  );

INSERT INTO content.items (title, body, content_type, created_by)
SELECT 'Demo Hunt Plan', 'Sample hunt plan for demo', 'plan', u.id
FROM auth.users u
WHERE u.username = 'demo2'
  AND NOT EXISTS (
    SELECT 1 FROM content.items c WHERE c.title = 'Demo Hunt Plan'
  );

-- Progress
INSERT INTO progress.user_progress (user_id, content_id, status, score)
SELECT u.id, c.id, 'completed', 95
FROM auth.users u
JOIN content.items c ON c.title = 'Welcome Guide'
WHERE u.username = 'demo1'
  AND NOT EXISTS (
    SELECT 1 FROM progress.user_progress p WHERE p.user_id = u.id AND p.content_id = c.id
  );

INSERT INTO progress.user_progress (user_id, content_id, status, score)
SELECT u.id, c.id, 'in_progress', 80
FROM auth.users u
JOIN content.items c ON c.title = 'Demo Hunt Plan'
WHERE u.username = 'demo2'
  AND NOT EXISTS (
    SELECT 1 FROM progress.user_progress p WHERE p.user_id = u.id AND p.content_id = c.id
  );

-- ML Models
INSERT INTO ml_infrastructure.model_registry (model_name, model_type, version, framework, model_url, status)
SELECT 'Demo Classifier', 'classification', 'v1.0', 'pytorch', 'https://models.hma/demo-classifier.pt', 'testing'
WHERE NOT EXISTS (
  SELECT 1 FROM ml_infrastructure.model_registry m WHERE m.model_name = 'Demo Classifier' AND m.version = 'v1.0'
);

INSERT INTO ml_infrastructure.model_registry (model_name, model_type, version, framework, model_url, status)
SELECT 'Demo Detector', 'object-detection', 'v1.0', 'tensorflow', 'https://models.hma/demo-detector.pb', 'testing'
WHERE NOT EXISTS (
  SELECT 1 FROM ml_infrastructure.model_registry m WHERE m.model_name = 'Demo Detector' AND m.version = 'v1.0'
);
