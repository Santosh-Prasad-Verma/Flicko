-- 1. Create robust transactional SQL function in Supabase
CREATE OR REPLACE FUNCTION public.redeem_gift_code(p_code text, p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_transaction record;
  v_redemption_id uuid;
  v_entitlement_id uuid;
  v_expiry timestamp with time zone;
BEGIN
  -- Find and lock the gift code row (FOR UPDATE locks the row securely)
  SELECT * INTO v_transaction
  FROM public.gift_transactions
  WHERE UPPER(gift_code) = UPPER(TRIM(p_code)) AND status = 'issued' AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid, expired, or already redeemed code.');
  END IF;

  -- Calculate new expiry boundary
  v_expiry := now() + (v_transaction.duration_days || ' days')::interval;

  -- Insert redemption logs
  v_redemption_id := gen_random_uuid();
  INSERT INTO public.gift_redemptions (id, gift_transaction_id, redeemer_id, redeemed_at, metadata, created_at)
  VALUES (v_redemption_id, v_transaction.id, p_user_id, now(), '{}'::jsonb, now());

  -- Create active entitlement benefit
  v_entitlement_id := gen_random_uuid();
  INSERT INTO public.entitlements (id, user_id, type, source, source_id, granted_at, expires_at, revoked)
  VALUES (v_entitlement_id, p_user_id, v_transaction.plan, 'gift', v_redemption_id, now(), v_expiry, false);

  -- Update gift transaction status
  UPDATE public.gift_transactions
  SET status = 'redeemed', redeemed_at = now(), redeemed_by = p_user_id, updated_at = now()
  WHERE id = v_transaction.id;

  -- Upsert active subscriptions mapping nitro_full (PRO) or nitro_basic (PLUS)
  DELETE FROM public.subscriptions WHERE user_id = p_user_id;

  INSERT INTO public.subscriptions (
    id, user_id, plan, status, store, current_period_start, current_period_end, cancel_at_period_end, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), p_user_id, v_transaction.plan, 'active', 'dev_mock', now(), v_expiry, false, now(), now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'plan', v_transaction.plan,
    'duration_days', v_transaction.duration_days,
    'price_cents', v_transaction.price_cents,
    'currency', v_transaction.currency
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Seed active test gift codes in gift_transactions
INSERT INTO public.gift_transactions (
  id, purchaser_id, plan, duration_days, price_cents, currency, gift_code, status, expires_at, metadata, created_at, updated_at
) VALUES 
(
  gen_random_uuid(), 
  '8b4a06cf-2b4a-4628-b4fd-f95b91df9428', -- Clay's user ID as purchaser
  'nitro_full', -- PRO subscription
  30, 
  159900, 
  'INR', 
  'FLICKO-PRO-30DAYS', 
  'issued', 
  now() + interval '365 days', 
  '{}'::jsonb, 
  now(), 
  now()
) ON CONFLICT (gift_code) DO UPDATE 
SET status = 'issued', expires_at = now() + interval '365 days', updated_at = now();

INSERT INTO public.gift_transactions (
  id, purchaser_id, plan, duration_days, price_cents, currency, gift_code, status, expires_at, metadata, created_at, updated_at
) VALUES 
(
  gen_random_uuid(), 
  '8b4a06cf-2b4a-4628-b4fd-f95b91df9428', 
  'nitro_basic', -- PLUS subscription
  30, 
  79900, 
  'INR', 
  'FLICKO-PLUS-30DAYS', 
  'issued', 
  now() + interval '365 days', 
  '{}'::jsonb, 
  now(), 
  now()
) ON CONFLICT (gift_code) DO UPDATE 
SET status = 'issued', expires_at = now() + interval '365 days', updated_at = now();
