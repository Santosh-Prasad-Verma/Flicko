-- Migration 154: Harden Security Definer Functions against Search Path Hijacking
-- Explicitly configures search_path = public, pg_catalog on 18 functions.

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
