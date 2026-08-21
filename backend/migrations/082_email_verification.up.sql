-- 082_email_verification.up.sql
-- Adds verification token storage to the users table for email verification flow.
-- The email_confirmed_at column already exists in the live schema.

-- Add verification token column (stores hashed 6-digit code)
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_token TEXT;

-- Add expiry timestamp for the verification token (24h default)
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_token_expires_at TIMESTAMPTZ;

-- Partial index: only index rows that actually have a pending token
CREATE INDEX IF NOT EXISTS idx_users_verification_token
  ON users(verification_token)
  WHERE verification_token IS NOT NULL;
