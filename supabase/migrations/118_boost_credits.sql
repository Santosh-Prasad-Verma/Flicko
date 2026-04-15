-- ============================================
-- Migration 118: Premium boost credits
-- ============================================
-- Story P5-E1-S2-T3

CREATE TABLE IF NOT EXISTS public.boost_credits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  consumed_at TIMESTAMPTZ,
  consumed_by_server_id UUID REFERENCES public.servers(id) ON DELETE SET NULL,
  source TEXT NOT NULL DEFAULT 'subscription'
    CHECK (source IN ('subscription', 'gift', 'grant', 'manual')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_boost_credits_user_expiry
  ON public.boost_credits(user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_boost_credits_user_consumed
  ON public.boost_credits(user_id, consumed_at);
CREATE INDEX IF NOT EXISTS idx_boost_credits_server_consumed
  ON public.boost_credits(consumed_by_server_id, consumed_at DESC);

DROP TRIGGER IF EXISTS tr_boost_credits_updated_at ON public.boost_credits;
CREATE TRIGGER tr_boost_credits_updated_at
  BEFORE UPDATE ON public.boost_credits
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.boost_credits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own boost credits" ON public.boost_credits;
CREATE POLICY "Users can read own boost credits"
  ON public.boost_credits FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own boost credits" ON public.boost_credits;
CREATE POLICY "Users can create own boost credits"
  ON public.boost_credits FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own boost credits" ON public.boost_credits;
CREATE POLICY "Users can update own boost credits"
  ON public.boost_credits FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own boost credits" ON public.boost_credits;
CREATE POLICY "Users can delete own boost credits"
  ON public.boost_credits FOR DELETE
  USING (user_id = auth.uid());
