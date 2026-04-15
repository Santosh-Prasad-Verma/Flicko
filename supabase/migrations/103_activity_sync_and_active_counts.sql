-- ============================================
-- Migration 103: Activity sync state + active counts
-- ============================================
-- Story P1-E2-S1/S2:
-- - Add synchronized media control state table.
-- - Add materialized view for active session counts per channel.

CREATE TABLE IF NOT EXISTS public.activity_sync_state (
  session_id UUID PRIMARY KEY REFERENCES public.activity_sessions(id) ON DELETE CASCADE,
  leader_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  playhead_ms BIGINT NOT NULL DEFAULT 0 CHECK (playhead_ms >= 0),
  is_playing BOOLEAN NOT NULL DEFAULT false,
  media_url TEXT DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_sync_state_leader ON public.activity_sync_state(leader_user_id);

ALTER TABLE public.activity_sync_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Server members can view activity sync state"
  ON public.activity_sync_state FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.activity_sessions s
      JOIN public.server_members sm ON sm.server_id = s.server_id
      WHERE s.id = activity_sync_state.session_id
        AND sm.user_id = auth.uid()
    )
  );

CREATE POLICY "Session participants can manage sync state"
  ON public.activity_sync_state FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM public.activity_participants p
      WHERE p.session_id = activity_sync_state.session_id
        AND p.user_id = auth.uid()
        AND p.left_at IS NULL
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.activity_participants p
      WHERE p.session_id = activity_sync_state.session_id
        AND p.user_id = auth.uid()
        AND p.left_at IS NULL
    )
  );

DROP MATERIALIZED VIEW IF EXISTS public.channel_active_activity_counts;
CREATE MATERIALIZED VIEW public.channel_active_activity_counts AS
SELECT
  s.channel_id,
  COUNT(*)::BIGINT AS active_session_count,
  MAX(COALESCE(s.last_heartbeat_at, s.created_at)) AS last_activity_at
FROM public.activity_sessions s
WHERE s.state IN ('launching', 'active')
  AND s.ended_at IS NULL
GROUP BY s.channel_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_channel_active_activity_counts_channel
  ON public.channel_active_activity_counts(channel_id);
