-- Migration 043: Push Notification Tokens
-- Stores device push tokens for per-device notification delivery.

-- ============================================================================
-- PUSH NOTIFICATION TOKENS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.push_notification_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  device_id TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, token)
);

CREATE INDEX idx_push_tokens_user ON public.push_notification_tokens(user_id)
  WHERE is_active = true;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.push_notification_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "push_tokens_select" ON public.push_notification_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "push_tokens_insert" ON public.push_notification_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "push_tokens_update" ON public.push_notification_tokens
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "push_tokens_delete" ON public.push_notification_tokens
  FOR DELETE USING (auth.uid() = user_id);
