-- Migration 044: Extended User Profile Columns
-- Adds accent_color, badges, custom_status_emoji, and custom_status_expires_at.
-- NOTE: banner and bio columns already exist from migration 001.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS accent_color TEXT DEFAULT '#5B4CFF',
  ADD COLUMN IF NOT EXISTS badges JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS custom_status_emoji TEXT,
  ADD COLUMN IF NOT EXISTS custom_status_expires_at TIMESTAMPTZ;

CREATE INDEX idx_profiles_custom_status ON public.profiles(custom_status_expires_at)
  WHERE custom_status_emoji IS NOT NULL;
