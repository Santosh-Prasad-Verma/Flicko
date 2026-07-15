-- Migration: Harden SECURITY DEFINER functions to prevent search path hijacking
-- Description: Sets the search_path configuration parameter on all security definer functions to pg_catalog, public.

ALTER FUNCTION public.has_permission(UUID, UUID, TEXT) SET search_path = pg_catalog, public;
ALTER FUNCTION public.has_server_permission(UUID, UUID, TEXT) SET search_path = pg_catalog, public;
ALTER FUNCTION public.get_mutual_servers(UUID, UUID) SET search_path = pg_catalog, public;
ALTER FUNCTION public.get_unread_counts(UUID) SET search_path = pg_catalog, public;
ALTER FUNCTION public.check_slowmode_allowed(UUID, UUID) SET search_path = pg_catalog, public;
ALTER FUNCTION public.handle_new_user() SET search_path = pg_catalog, public;
ALTER FUNCTION public.handle_new_server() SET search_path = pg_catalog, public;
ALTER FUNCTION public.handle_mention_notifications() SET search_path = pg_catalog, public;
ALTER FUNCTION public.handle_friend_request_notification() SET search_path = pg_catalog, public;
