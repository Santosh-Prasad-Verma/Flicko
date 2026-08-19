-- Migration 041: Message Replies System
-- Note: The messages.reply_to_id column already exists (migration 037).
-- This migration adds a dedicated message_replies table for richer reply
-- metadata, and ensures indexes are in place for efficient lookups.

-- ============================================================================
-- MESSAGE REPLIES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.message_replies (
  message_id UUID PRIMARY KEY REFERENCES public.messages(id) ON DELETE CASCADE,
  replied_to_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_message_replies_replied_to ON public.message_replies(replied_to_id);

-- Ensure the existing reply_to_id column on messages has an index
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON public.messages(reply_to_id)
  WHERE reply_to_id IS NOT NULL;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.message_replies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "message_replies_select" ON public.message_replies
  FOR SELECT USING (true);

CREATE POLICY "message_replies_insert" ON public.message_replies
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.messages WHERE id = message_id AND author_id = auth.uid())
  );
