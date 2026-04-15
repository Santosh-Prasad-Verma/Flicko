-- ============================================
-- Migration 115: Voice admin actions and channel user limits
-- ============================================
-- Story P4-E1-S2-T3

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'channels'
      AND column_name = 'user_limit'
  ) THEN
    ALTER TABLE public.channels
      ADD COLUMN user_limit INTEGER NOT NULL DEFAULT 0 CHECK (user_limit >= 0 AND user_limit <= 99);
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.voice_admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  target_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL
    CHECK (action_type IN ('move_user', 'update_user_limit')),
  action_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_voice_admin_actions_server_created
  ON public.voice_admin_actions(server_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voice_admin_actions_channel_created
  ON public.voice_admin_actions(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voice_admin_actions_actor_created
  ON public.voice_admin_actions(actor_id, created_at DESC);

ALTER TABLE public.voice_admin_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read voice admin actions for joined servers" ON public.voice_admin_actions;
CREATE POLICY "Users can read voice admin actions for joined servers"
  ON public.voice_admin_actions FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = voice_admin_actions.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create voice admin actions for joined servers" ON public.voice_admin_actions;
CREATE POLICY "Users can create voice admin actions for joined servers"
  ON public.voice_admin_actions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = voice_admin_actions.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own voice admin actions" ON public.voice_admin_actions;
CREATE POLICY "Users can update own voice admin actions"
  ON public.voice_admin_actions FOR UPDATE
  USING (actor_id = auth.uid())
  WITH CHECK (actor_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own voice admin actions" ON public.voice_admin_actions;
CREATE POLICY "Users can delete own voice admin actions"
  ON public.voice_admin_actions FOR DELETE
  USING (actor_id = auth.uid());
