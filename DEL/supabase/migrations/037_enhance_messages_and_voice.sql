-- 037_enhance_messages_and_voice.sql
-- Adds missing columns for message editing, reply references, and voice states

-- 1. Add reply_to_id to messages if not exists
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'messages' AND column_name = 'reply_to_id'
  ) THEN
    ALTER TABLE public.messages ADD COLUMN reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;
    CREATE INDEX idx_messages_reply_to ON public.messages(reply_to_id) WHERE reply_to_id IS NOT NULL;
  END IF;
END $$;

-- 2. Add edited boolean flag if not exists (edited_at already exists from 005)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'messages' AND column_name = 'edited'
  ) THEN
    ALTER TABLE public.messages ADD COLUMN edited BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

-- 3. Add updated_at column if not exists
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'messages' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.messages ADD COLUMN updated_at TIMESTAMPTZ;
  END IF;
END $$;

-- 4. Create trigger to auto-set edited + updated_at on message update
CREATE OR REPLACE FUNCTION public.handle_message_edit()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content <> OLD.content THEN
    NEW.edited := true;
    NEW.edited_at := NOW();
    NEW.updated_at := NOW();

    -- Record edit history
    INSERT INTO public.message_edit_history (message_id, old_content, new_content, edited_by)
    VALUES (OLD.id, OLD.content, NEW.content, NEW.author_id)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_message_edit ON public.messages;
CREATE TRIGGER trigger_message_edit
  BEFORE UPDATE ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_message_edit();

-- 5. Add suppress column to voice_states for stage channels
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'voice_states' AND column_name = 'suppress'
  ) THEN
    ALTER TABLE public.voice_states ADD COLUMN suppress BOOLEAN NOT NULL DEFAULT false;
  END IF;
END $$;

-- 6. Create voice_connection_logs for tracking connection quality
CREATE TABLE IF NOT EXISTS public.voice_connection_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('connecting', 'connected', 'disconnected', 'reconnecting', 'failed')),
  quality_score INTEGER CHECK (quality_score >= 0 AND quality_score <= 100),
  latency_ms INTEGER,
  packet_loss_percent NUMERIC(5,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_voice_conn_logs_user ON public.voice_connection_logs(user_id, created_at DESC);
CREATE INDEX idx_voice_conn_logs_channel ON public.voice_connection_logs(channel_id, created_at DESC);

-- 7. Add thread_id to messages for thread replies
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'messages' AND column_name = 'thread_id'
  ) THEN
    ALTER TABLE public.messages ADD COLUMN thread_id UUID REFERENCES public.threads(id) ON DELETE SET NULL;
    CREATE INDEX idx_messages_thread ON public.messages(thread_id) WHERE thread_id IS NOT NULL;
  END IF;
END $$;

-- 8. RLS policies for voice_connection_logs
ALTER TABLE public.voice_connection_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own voice logs"
  ON public.voice_connection_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own voice logs"
  ON public.voice_connection_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 9. RLS policies for threads (if not already set)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'threads' AND policyname = 'Members can view threads'
  ) THEN
    ALTER TABLE public.threads ENABLE ROW LEVEL SECURITY;

    EXECUTE 'CREATE POLICY "Members can view threads"
      ON public.threads FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.server_members sm
          WHERE sm.server_id = threads.server_id
          AND sm.user_id = auth.uid()
        )
      )';

    EXECUTE 'CREATE POLICY "Members can create threads"
      ON public.threads FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.server_members sm
          WHERE sm.server_id = threads.server_id
          AND sm.user_id = auth.uid()
        )
      )';

    EXECUTE 'CREATE POLICY "Thread creator can update"
      ON public.threads FOR UPDATE
      USING (creator_id = auth.uid())';
  END IF;
END $$;

-- 10. RLS for thread_members
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'thread_members' AND policyname = 'Thread members can view'
  ) THEN
    ALTER TABLE public.thread_members ENABLE ROW LEVEL SECURITY;

    EXECUTE 'CREATE POLICY "Thread members can view"
      ON public.thread_members FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.thread_members tm
          WHERE tm.thread_id = thread_members.thread_id
          AND tm.user_id = auth.uid()
        )
      )';

    EXECUTE 'CREATE POLICY "Users can join threads"
      ON public.thread_members FOR INSERT
      WITH CHECK (auth.uid() = user_id)';

    EXECUTE 'CREATE POLICY "Users can leave threads"
      ON public.thread_members FOR DELETE
      USING (auth.uid() = user_id)';
  END IF;
END $$;
