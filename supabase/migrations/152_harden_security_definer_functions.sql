-- Migration: Harden SECURITY DEFINER functions to prevent search path hijacking (Hardened with checks)
-- Description: Sets the search_path configuration parameter on all security definer functions only if they exist.

-- 1. has_permission
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'has_permission'
  ) THEN
    ALTER FUNCTION public.has_permission(UUID, UUID, TEXT) SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 2. has_server_permission
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'has_server_permission'
  ) THEN
    ALTER FUNCTION public.has_server_permission(UUID, UUID, TEXT) SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 3. get_mutual_servers
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_mutual_servers'
  ) THEN
    ALTER FUNCTION public.get_mutual_servers(UUID, UUID) SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 4. get_unread_counts
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_unread_counts'
  ) THEN
    ALTER FUNCTION public.get_unread_counts(UUID) SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 5. check_slowmode_allowed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'check_slowmode_allowed'
  ) THEN
    ALTER FUNCTION public.check_slowmode_allowed(UUID, UUID) SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 6. handle_new_user
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'handle_new_user'
  ) THEN
    ALTER FUNCTION public.handle_new_user() SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 7. handle_new_server
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'handle_new_server'
  ) THEN
    ALTER FUNCTION public.handle_new_server() SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 8. handle_mention_notifications
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'handle_mention_notifications'
  ) THEN
    ALTER FUNCTION public.handle_mention_notifications() SET search_path = pg_catalog, public;
  END IF;
END $$;

-- 9. handle_friend_request_notification
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc p 
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'handle_friend_request_notification'
  ) THEN
    ALTER FUNCTION public.handle_friend_request_notification() SET search_path = pg_catalog, public;
  END IF;
END $$;
