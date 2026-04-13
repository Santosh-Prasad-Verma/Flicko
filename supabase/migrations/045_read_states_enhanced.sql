-- Migration 045: Enhanced Read States
-- Adds last_viewed_at to channel_read_states for more precise unread tracking.
-- NOTE: mention_count column already exists from migration 038.

ALTER TABLE public.channel_read_states
  ADD COLUMN IF NOT EXISTS last_viewed_at TIMESTAMPTZ;

-- Backfill from updated_at
UPDATE public.channel_read_states
  SET last_viewed_at = updated_at
  WHERE last_viewed_at IS NULL AND updated_at IS NOT NULL;
