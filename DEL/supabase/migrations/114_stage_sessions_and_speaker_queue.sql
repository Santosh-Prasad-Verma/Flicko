-- ============================================
-- Migration 114: Stage sessions and speaker queue
-- ============================================
-- Story P4-E1-S1-T3

CREATE TABLE IF NOT EXISTS public.stage_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'ended')),
  topic TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stage_sessions_channel_status
  ON public.stage_sessions(channel_id, status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_stage_sessions_server_status
  ON public.stage_sessions(server_id, status, started_at DESC);

DROP TRIGGER IF EXISTS tr_stage_sessions_updated_at ON public.stage_sessions;
CREATE TRIGGER tr_stage_sessions_updated_at
  BEFORE UPDATE ON public.stage_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.stage_speaker_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.stage_sessions(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position > 0),
  status TEXT NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting', 'promoted', 'dismissed', 'cancelled')),
  hand_raised_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  promoted_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_stage_speaker_queue_active_user
  ON public.stage_speaker_queue(session_id, user_id)
  WHERE status = 'waiting';
CREATE INDEX IF NOT EXISTS idx_stage_speaker_queue_session_waiting_position
  ON public.stage_speaker_queue(session_id, status, position, hand_raised_at);
CREATE INDEX IF NOT EXISTS idx_stage_speaker_queue_user
  ON public.stage_speaker_queue(user_id, hand_raised_at DESC);

DROP TRIGGER IF EXISTS tr_stage_speaker_queue_updated_at ON public.stage_speaker_queue;
CREATE TRIGGER tr_stage_speaker_queue_updated_at
  BEFORE UPDATE ON public.stage_speaker_queue
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.stage_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stage_speaker_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read stage sessions for joined servers" ON public.stage_sessions;
CREATE POLICY "Users can read stage sessions for joined servers"
  ON public.stage_sessions FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = stage_sessions.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create stage sessions for joined servers" ON public.stage_sessions;
CREATE POLICY "Users can create stage sessions for joined servers"
  ON public.stage_sessions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = stage_sessions.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update stage sessions they created" ON public.stage_sessions;
CREATE POLICY "Users can update stage sessions they created"
  ON public.stage_sessions FOR UPDATE
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "Users can delete stage sessions they created" ON public.stage_sessions;
CREATE POLICY "Users can delete stage sessions they created"
  ON public.stage_sessions FOR DELETE
  USING (created_by = auth.uid());

DROP POLICY IF EXISTS "Users can read stage queue for joined servers" ON public.stage_speaker_queue;
CREATE POLICY "Users can read stage queue for joined servers"
  ON public.stage_speaker_queue FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = stage_speaker_queue.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create own stage queue entries" ON public.stage_speaker_queue;
CREATE POLICY "Users can create own stage queue entries"
  ON public.stage_speaker_queue FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own stage queue entries" ON public.stage_speaker_queue;
CREATE POLICY "Users can update own stage queue entries"
  ON public.stage_speaker_queue FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own stage queue entries" ON public.stage_speaker_queue;
CREATE POLICY "Users can delete own stage queue entries"
  ON public.stage_speaker_queue FOR DELETE
  USING (user_id = auth.uid());
