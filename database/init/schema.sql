-- Consolidated starter schema applying key parts of the intent (stub)
-- Auth and ML Infrastructure core tables can be broken into migrations later.

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS ml_infrastructure;
CREATE SCHEMA IF NOT EXISTS content;

-- Minimal auth.users matching extended intent (subset)
CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  birth_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'pending_verification',
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ML registry (subset)
CREATE TABLE IF NOT EXISTS ml_infrastructure.model_registry (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  model_name VARCHAR(255) NOT NULL,
  model_type VARCHAR(50),
  version VARCHAR(20) NOT NULL,
  framework VARCHAR(50) NOT NULL,
  model_url TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'testing',
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Content assets (subset)
CREATE TABLE IF NOT EXISTS content.assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_code VARCHAR(100) UNIQUE NOT NULL,
  asset_type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  file_url TEXT NOT NULL,
  tags TEXT[],
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
