-- Backend Down Migration 080: Rollback Search Path Hardening
-- Resets search_path settings on the 18 altered functions.

ALTER FUNCTION public.handle_creator_post_like() RESET search_path;
ALTER FUNCTION public.handle_creator_post_repost() RESET search_path;
ALTER FUNCTION public.update_thread_archive_time() RESET search_path;
ALTER FUNCTION public.track_invite_usage() RESET search_path;
ALTER FUNCTION public.update_server_boost_level() RESET search_path;
ALTER FUNCTION public.increment_emoji_usage(emoji_uuid uuid) RESET search_path;
ALTER FUNCTION public.search_messages_with_highlights(search_query text, channel_ids uuid[], result_limit integer, result_offset integer, sort_order text) RESET search_path;
ALTER FUNCTION public.dev_grant_nitro(target_user_id uuid, nitro_plan text) RESET search_path;
ALTER FUNCTION public.get_slowmode_remaining_seconds(p_channel_id uuid) RESET search_path;
ALTER FUNCTION public.check_friend_request_privacy() RESET search_path;
ALTER FUNCTION public.check_username_exists(target_username text) RESET search_path;
ALTER FUNCTION public.handle_creator_post_reply() RESET search_path;
ALTER FUNCTION public.redeem_gift_code(p_code text, p_user_id uuid) RESET search_path;
ALTER FUNCTION public.handle_message_mentions() RESET search_path;
ALTER FUNCTION public.handle_dm_notification() RESET search_path;
ALTER FUNCTION public.enforce_auto_mod_rules() RESET search_path;
ALTER FUNCTION public.handle_direct_message_notification() RESET search_path;
ALTER FUNCTION public.handle_message_mention() RESET search_path;
