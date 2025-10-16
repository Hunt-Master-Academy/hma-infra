-- ============================================================================
-- Create Superadmin Account
-- ============================================================================
-- Purpose: Set up the official Hunt Master Academy superadmin account
-- Domain: Only @huntmasteracademy.com emails are allowed for admin accounts
-- Account: info@huntmasteracademy.com (superadmin)
-- ============================================================================

BEGIN;

-- Step 1: Remove all existing admin accounts
-- First, update foreign key references to NULL where possible
DO $$
BEGIN
  -- Update credit_system_config to remove admin user references
  UPDATE credit_system_config SET updated_by = NULL WHERE updated_by IN (
    SELECT id FROM users WHERE user_type = 'admin'
  );
  
  -- Now safe to delete admin users
  DELETE FROM users WHERE user_type = 'admin';
  
  RAISE NOTICE 'Purged all existing admin accounts and updated foreign key references';
END $$;

-- Step 2: Create the official superadmin account
-- Password: Admin123!HMA (will be hashed using pgcrypto)
-- Email: info@huntmasteracademy.com
-- Type: admin (superadmin privileges)
-- Status: Email pre-verified for immediate access

-- Ensure pgcrypto extension is available
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (
  id,
  email,
  password_hash,
  first_name,
  last_name,
  user_type,
  email_verified,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'info@huntmasteracademy.com',
  crypt('Admin123!HMA', gen_salt('bf', 12)), -- Hash password with bcrypt
  'Hunt Master',
  'Administrator',
  'admin',
  true, -- Pre-verified for alpha/dev testing
  NOW(),
  NOW()
)
ON CONFLICT (email) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  user_type = EXCLUDED.user_type,
  email_verified = EXCLUDED.email_verified,
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  updated_at = NOW();

DO $$
BEGIN
  RAISE NOTICE 'Created superadmin account: info@huntmasteracademy.com';
END $$;

-- Step 3: Verify the account was created
DO $$
DECLARE
  admin_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO admin_count FROM users WHERE user_type = 'admin';
  RAISE NOTICE 'Total admin accounts: %', admin_count;
  
  IF admin_count != 1 THEN
    RAISE EXCEPTION 'Expected exactly 1 admin account, found %', admin_count;
  END IF;
  
  RAISE NOTICE '✅ Superadmin setup complete!';
END $$;

COMMIT;
