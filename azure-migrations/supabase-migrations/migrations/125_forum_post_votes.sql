-- ============================================
-- Migration 125: Forum post votes
-- ============================================
-- Story P8-E1-S2-T2

CREATE TABLE IF NOT EXISTS public.forum_post_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES public.threads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vote SMALLINT NOT NULL DEFAULT 1 CHECK (vote IN (-1, 1)),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(thread_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_post_votes_thread_created
  ON public.forum_post_votes(thread_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_post_votes_user_created
  ON public.forum_post_votes(user_id, created_at DESC);

DROP TRIGGER IF EXISTS tr_forum_post_votes_updated_at ON public.forum_post_votes;
CREATE TRIGGER tr_forum_post_votes_updated_at
  BEFORE UPDATE ON public.forum_post_votes
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.forum_post_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read votes for joined-server threads" ON public.forum_post_votes;
CREATE POLICY "Users can read votes for joined-server threads"
  ON public.forum_post_votes FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.threads t
      JOIN public.server_members sm ON sm.server_id = t.server_id
      WHERE t.id = forum_post_votes.thread_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create own votes for joined-server threads" ON public.forum_post_votes;
CREATE POLICY "Users can create own votes for joined-server threads"
  ON public.forum_post_votes FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.threads t
      JOIN public.server_members sm ON sm.server_id = t.server_id
      WHERE t.id = forum_post_votes.thread_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own votes" ON public.forum_post_votes;
CREATE POLICY "Users can update own votes"
  ON public.forum_post_votes FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own votes" ON public.forum_post_votes;
CREATE POLICY "Users can delete own votes"
  ON public.forum_post_votes FOR DELETE
  USING (user_id = auth.uid());
