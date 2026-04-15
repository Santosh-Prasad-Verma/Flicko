-- ============================================
-- Migration 106: MFA factors and recovery codes
-- ============================================
-- Story P2-E1-S1-T4

CREATE TABLE IF NOT EXISTS public.mfa_factors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  factor_type TEXT NOT NULL DEFAULT 'totp' CHECK (factor_type IN ('totp')),
  secret TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT false,
  verified_at TIMESTAMPTZ,
  disabled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mfa_factors_user_id ON public.mfa_factors(user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_factors_enabled ON public.mfa_factors(enabled) WHERE disabled_at IS NULL;

DROP TRIGGER IF EXISTS tr_mfa_factors_updated_at ON public.mfa_factors;
CREATE TRIGGER tr_mfa_factors_updated_at
  BEFORE UPDATE ON public.mfa_factors
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.mfa_recovery_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  factor_id UUID NOT NULL REFERENCES public.mfa_factors(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(factor_id, code_hash)
);

CREATE INDEX IF NOT EXISTS idx_mfa_recovery_codes_user_id ON public.mfa_recovery_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_recovery_codes_factor_id ON public.mfa_recovery_codes(factor_id);
CREATE INDEX IF NOT EXISTS idx_mfa_recovery_codes_unused ON public.mfa_recovery_codes(user_id) WHERE used_at IS NULL;

ALTER TABLE public.mfa_factors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mfa_recovery_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own mfa factors" ON public.mfa_factors;
CREATE POLICY "Users can read own mfa factors"
  ON public.mfa_factors FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own mfa factors" ON public.mfa_factors;
CREATE POLICY "Users can create own mfa factors"
  ON public.mfa_factors FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own mfa factors" ON public.mfa_factors;
CREATE POLICY "Users can update own mfa factors"
  ON public.mfa_factors FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own mfa factors" ON public.mfa_factors;
CREATE POLICY "Users can delete own mfa factors"
  ON public.mfa_factors FOR DELETE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read own mfa recovery codes" ON public.mfa_recovery_codes;
CREATE POLICY "Users can read own mfa recovery codes"
  ON public.mfa_recovery_codes FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own mfa recovery codes" ON public.mfa_recovery_codes;
CREATE POLICY "Users can create own mfa recovery codes"
  ON public.mfa_recovery_codes FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own mfa recovery codes" ON public.mfa_recovery_codes;
CREATE POLICY "Users can update own mfa recovery codes"
  ON public.mfa_recovery_codes FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own mfa recovery codes" ON public.mfa_recovery_codes;
CREATE POLICY "Users can delete own mfa recovery codes"
  ON public.mfa_recovery_codes FOR DELETE
  USING (user_id = auth.uid());
