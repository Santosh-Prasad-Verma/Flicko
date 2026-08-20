-- Migration: Fix check_slowmode_allowed and has_permission functions
-- The check_slowmode_allowed function had an incorrect JOIN using sm.role_id (which does not exist on server_members).
-- The has_permission function returned NULL instead of FALSE when no user specific or role overwrites existed because PL/pgSQL SELECT INTO sets variables to NULL if no rows are found.

CREATE OR REPLACE FUNCTION public.has_permission(
  target_user_uuid UUID,
  target_channel_uuid UUID,
  permission_name TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  target_server_uuid UUID;
  is_owner BOOLEAN;
  base_permissions BIGINT := 0;
  overwrite_allow BIGINT := 0;
  overwrite_deny BIGINT := 0;
  final_permissions BIGINT := 0;
  perm_bit BIGINT;
BEGIN
  -- Get the permission bit we are checking for
  perm_bit := public.get_permission_bit(permission_name);
  IF perm_bit = 0 THEN
    RETURN FALSE; -- Invalid permission requested
  END IF;

  -- 1. Get the server ID for this channel
  SELECT server_id INTO target_server_uuid FROM public.channels WHERE id = target_channel_uuid;
  IF target_server_uuid IS NULL THEN
    RETURN FALSE; -- Channel doesn't exist
  END IF;

  -- 2. Check if user is server owner (Owner has all permissions implicitly)
  SELECT owner_id = target_user_uuid INTO is_owner FROM public.servers WHERE id = target_server_uuid;
  IF is_owner THEN
    RETURN TRUE;
  END IF;

  -- 3. Calculate Base Permissions (from server_members and roles)
  SELECT COALESCE(BIT_OR(r.permissions::bigint), 0)
  INTO base_permissions
  FROM public.server_members sm
  CROSS JOIN LATERAL unnest(sm.roles) AS role_id
  JOIN public.roles r ON r.id = role_id
  WHERE sm.user_id = target_user_uuid AND sm.server_id = target_server_uuid;

  base_permissions := COALESCE(base_permissions, 0);

  -- 4. Check for ADMINISTRATOR permission
  IF (base_permissions & public.get_permission_bit('ADMINISTRATOR')) = public.get_permission_bit('ADMINISTRATOR') THEN
    RETURN TRUE;
  END IF;

  -- 5. Apply Channel Overwrites
  -- We process role overwrites first, then user overwrites taking precedence
  
  -- 5a. Role Overwrites
  SELECT 
    COALESCE(BIT_OR(po.allow), 0),
    COALESCE(BIT_OR(po.deny), 0)
  INTO overwrite_allow, overwrite_deny
  FROM public.permission_overwrites po
  JOIN public.server_members sm ON sm.user_id = target_user_uuid AND sm.server_id = target_server_uuid
  WHERE po.channel_id = target_channel_uuid
    AND po.target_type = 'role'
    AND po.target_id = ANY(sm.roles);

  overwrite_allow := COALESCE(overwrite_allow, 0);
  overwrite_deny := COALESCE(overwrite_deny, 0);

  base_permissions := (base_permissions & ~overwrite_deny) | overwrite_allow;

  -- Reset overwrite variables for user specific check
  overwrite_allow := 0;
  overwrite_deny := 0;

  -- 5b. User Specific Overwrites
  SELECT 
    COALESCE(po.allow, 0),
    COALESCE(po.deny, 0)
  INTO overwrite_allow, overwrite_deny
  FROM public.permission_overwrites po
  WHERE po.channel_id = target_channel_uuid
    AND po.target_type = 'user'
    AND po.target_id = target_user_uuid;

  overwrite_allow := COALESCE(overwrite_allow, 0);
  overwrite_deny := COALESCE(overwrite_deny, 0);

  -- 6. Calculate Final Permission
  final_permissions := (base_permissions & ~overwrite_deny) | overwrite_allow;

  -- 7. Return true if the requested permission bit is set in the final permissions
  RETURN (final_permissions & perm_bit) = perm_bit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.check_slowmode_allowed(p_channel_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_slowmode_delay    INT;
    v_last_message_time TIMESTAMPTZ;
    v_is_moderator      BOOLEAN;
BEGIN
    -- Get channel slowmode setting.
    SELECT slowmode_seconds INTO v_slowmode_delay
    FROM public.channels
    WHERE id = p_channel_id;

    -- No slowmode configured: allow.
    IF v_slowmode_delay IS NULL OR v_slowmode_delay = 0 THEN
        RETURN TRUE;
    END IF;

    -- Moderators (MANAGE_MESSAGES) bypass slowmode.
    v_is_moderator := public.has_permission(p_user_id, p_channel_id, 'MANAGE_MESSAGES');
    IF v_is_moderator THEN
        RETURN TRUE;
    END IF;

    -- Time of this user's last message in this channel.
    SELECT created_at INTO v_last_message_time
    FROM public.messages
    WHERE channel_id = p_channel_id AND author_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_message_time IS NULL THEN
        RETURN TRUE;
    END IF;

    RETURN EXTRACT(EPOCH FROM (now() - v_last_message_time)) >= v_slowmode_delay;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
