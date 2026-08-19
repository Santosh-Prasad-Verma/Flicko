-- Migration 042: Offline Message Queue
-- Client-side queue is primary (AsyncStorage), but this server table
-- supports cross-device queue sync and duplicate detection via idempotency keys.

-- ============================================================================
-- OFFLINE MESSAGE QUEUE TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.offline_message_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000),
  attachments JSONB DEFAULT '[]',
  reply_to_id UUID,
  client_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
  retry_count INTEGER NOT NULL DEFAULT 0,
  last_retry_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, client_id)
);

CREATE INDEX idx_offline_queue_user ON public.offline_message_queue(user_id);
CREATE INDEX idx_offline_queue_status ON public.offline_message_queue(status)
  WHERE status IN ('pending', 'processing');

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.offline_message_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "offline_queue_select" ON public.offline_message_queue
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "offline_queue_insert" ON public.offline_message_queue
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "offline_queue_update" ON public.offline_message_queue
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "offline_queue_delete" ON public.offline_message_queue
  FOR DELETE USING (auth.uid() = user_id);
