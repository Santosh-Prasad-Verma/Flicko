-- ============================================
-- Migration 117: Premium gift transactions and redemptions
-- ============================================
-- Story P5-E1-S1-T3

CREATE TABLE IF NOT EXISTS public.gift_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchaser_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan TEXT NOT NULL CHECK (plan IN ('nitro_basic', 'nitro_full')),
  duration_days INTEGER NOT NULL DEFAULT 30 CHECK (duration_days > 0 AND duration_days <= 365),
  price_cents INTEGER NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
  currency TEXT NOT NULL DEFAULT 'usd',
  gift_code TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'issued'
    CHECK (status IN ('issued', 'redeemed', 'expired', 'cancelled')),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  redeemed_at TIMESTAMPTZ,
  redeemed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gift_transactions_purchaser
  ON public.gift_transactions(purchaser_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gift_transactions_status_expires
  ON public.gift_transactions(status, expires_at);
CREATE INDEX IF NOT EXISTS idx_gift_transactions_redeemed_by
  ON public.gift_transactions(redeemed_by, redeemed_at DESC);

DROP TRIGGER IF EXISTS tr_gift_transactions_updated_at ON public.gift_transactions;
CREATE TRIGGER tr_gift_transactions_updated_at
  BEFORE UPDATE ON public.gift_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.gift_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gift_transaction_id UUID NOT NULL UNIQUE REFERENCES public.gift_transactions(id) ON DELETE CASCADE,
  redeemer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entitlement_id UUID REFERENCES public.entitlements(id) ON DELETE SET NULL,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gift_redemptions_redeemer
  ON public.gift_redemptions(redeemer_id, redeemed_at DESC);

ALTER TABLE public.gift_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gift_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own or redeemed gift transactions" ON public.gift_transactions;
CREATE POLICY "Users can read own or redeemed gift transactions"
  ON public.gift_transactions FOR SELECT
  USING (purchaser_id = auth.uid() OR redeemed_by = auth.uid());

DROP POLICY IF EXISTS "Users can create own gift transactions" ON public.gift_transactions;
CREATE POLICY "Users can create own gift transactions"
  ON public.gift_transactions FOR INSERT
  WITH CHECK (purchaser_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own or redeemed gift transactions" ON public.gift_transactions;
CREATE POLICY "Users can update own or redeemed gift transactions"
  ON public.gift_transactions FOR UPDATE
  USING (purchaser_id = auth.uid() OR redeemed_by = auth.uid())
  WITH CHECK (purchaser_id = auth.uid() OR redeemed_by = auth.uid());

DROP POLICY IF EXISTS "Users can delete own gift transactions" ON public.gift_transactions;
CREATE POLICY "Users can delete own gift transactions"
  ON public.gift_transactions FOR DELETE
  USING (purchaser_id = auth.uid());

DROP POLICY IF EXISTS "Users can read own gift redemptions" ON public.gift_redemptions;
CREATE POLICY "Users can read own gift redemptions"
  ON public.gift_redemptions FOR SELECT
  USING (redeemer_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own gift redemptions" ON public.gift_redemptions;
CREATE POLICY "Users can create own gift redemptions"
  ON public.gift_redemptions FOR INSERT
  WITH CHECK (redeemer_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own gift redemptions" ON public.gift_redemptions;
CREATE POLICY "Users can update own gift redemptions"
  ON public.gift_redemptions FOR UPDATE
  USING (redeemer_id = auth.uid())
  WITH CHECK (redeemer_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own gift redemptions" ON public.gift_redemptions;
CREATE POLICY "Users can delete own gift redemptions"
  ON public.gift_redemptions FOR DELETE
  USING (redeemer_id = auth.uid());
