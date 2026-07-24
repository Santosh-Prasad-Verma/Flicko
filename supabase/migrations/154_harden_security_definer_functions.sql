-- Migration 154: Harden Security Definer Functions against Search Path Hijacking
-- Explicitly configures search_path = public, pg_catalog on 18 functions.

-- ---------------------------------------------------------------------------
-- Drift fix: five of the functions ALTERed below were created out-of-band and
-- were never present in committed migrations, so a clean apply (CI) failed with
-- "function ... does not exist" before this migration could run. Recreate them
-- here (exact live definitions) so migrations apply cleanly from scratch.
-- CREATE OR REPLACE is idempotent and prod already has 154 recorded as applied,
-- so this changes nothing on prod; plpgsql bodies are late-bound so no table
-- ordering is required.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_friend_request_privacy()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  target_allow BOOLEAN;
BEGIN
  -- only check outgoing requests (status = 'pending' or similar)
  IF (NEW.status = 'pending' OR NEW.status = '0') THEN
    SELECT allow_friend_requests_from_everyone INTO target_allow
    FROM public.user_privacy_settings
    WHERE user_id = NEW.friend_id;

    IF NOT COALESCE(target_allow, true) THEN
      RAISE EXCEPTION 'Target user does not accept friend requests from everyone.';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_username_exists(target_username text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles WHERE username = target_username
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_dm_notification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  sender_record RECORD;
  display_name_or_username TEXT;
BEGIN
  -- Get sender info
  SELECT display_name, username INTO sender_record
  FROM public.profiles
  WHERE id = NEW.sender_id;

  display_name_or_username := COALESCE(sender_record.display_name, sender_record.username, 'Someone');

  -- Insert notification for the recipient
  INSERT INTO public.notifications (user_id, type, content, read)
  VALUES (
    NEW.recipient_id,
    'dm',
    jsonb_build_object(
      'userName', display_name_or_username,
      'content', 'sent you a direct message',
      'preview', COALESCE(NEW.content, 'Sent an attachment'),
      'userId', NEW.sender_id
    ),
    false
  );

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_message_mentions()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  mentioned_user_record RECORD;
  sender_record RECORD;
  username_match RECORD;
  display_name_or_username TEXT;
BEGIN
  -- Get sender info
  SELECT display_name, username INTO sender_record
  FROM public.profiles
  WHERE id = NEW.author_id;

  display_name_or_username := COALESCE(sender_record.display_name, sender_record.username, 'Someone');

  -- Parse all @username mentions from content
  FOR username_match IN
    SELECT DISTINCT (regexp_matches(NEW.content, '@([a-zA-Z0-9_.-]+)', 'g'))[1] AS username
  LOOP
    -- Look up mentioned user
    SELECT id INTO mentioned_user_record
    FROM public.profiles
    WHERE LOWER(username) = LOWER(username_match.username);

    -- If user exists and is not the author, insert notification
    IF mentioned_user_record.id IS NOT NULL AND mentioned_user_record.id != NEW.author_id THEN
      INSERT INTO public.notifications (user_id, type, content, read)
      VALUES (
        mentioned_user_record.id,
        'mention',
        jsonb_build_object(
          'userName', display_name_or_username,
          'content', 'mentioned you in a message',
          'preview', NEW.content,
          'channelId', NEW.channel_id,
          'messageId', NEW.id
        ),
        false
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.redeem_gift_code(p_code text, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
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
$function$;

ALTER FUNCTION public.handle_creator_post_like() SET search_path = public, pg_catalog;
ALTER FUNCTION public.handle_creator_post_repost() SET search_path = public, pg_catalog;
ALTER FUNCTION public.update_thread_archive_time() SET search_path = public, pg_catalog;
ALTER FUNCTION public.track_invite_usage() SET search_path = public, pg_catalog;
ALTER FUNCTION public.update_server_boost_level() SET search_path = public, pg_catalog;
ALTER FUNCTION public.increment_emoji_usage(emoji_uuid uuid) SET search_path = public, pg_catalog;
ALTER FUNCTION public.search_messages_with_highlights(search_query text, channel_ids uuid[], result_limit integer, result_offset integer, sort_order text) SET search_path = public, pg_catalog;
ALTER FUNCTION public.dev_grant_nitro(target_user_id uuid, nitro_plan text) SET search_path = public, pg_catalog;
ALTER FUNCTION public.get_slowmode_remaining_seconds(p_channel_id uuid) SET search_path = public, pg_catalog;
ALTER FUNCTION public.check_friend_request_privacy() SET search_path = public, pg_catalog;
ALTER FUNCTION public.check_username_exists(target_username text) SET search_path = public, pg_catalog;
ALTER FUNCTION public.handle_creator_post_reply() SET search_path = public, pg_catalog;
ALTER FUNCTION public.redeem_gift_code(p_code text, p_user_id uuid) SET search_path = public, pg_catalog;
ALTER FUNCTION public.handle_message_mentions() SET search_path = public, pg_catalog;
ALTER FUNCTION public.handle_dm_notification() SET search_path = public, pg_catalog;
ALTER FUNCTION public.enforce_auto_mod_rules() SET search_path = public, pg_catalog;
ALTER FUNCTION public.handle_direct_message_notification() SET search_path = public, pg_catalog;
ALTER FUNCTION public.handle_message_mention() SET search_path = public, pg_catalog;
