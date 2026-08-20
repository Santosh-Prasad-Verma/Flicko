-- 035_permission_calculation_functions.sql

-- Helper function to map permission names to their bitwise integer values
CREATE OR REPLACE FUNCTION public.get_permission_bit(permission_name TEXT)
RETURNS BIGINT AS $$
DECLARE
  -- Standard Discord-like integer permissions bitmask values
  CREATE_INSTANT_INVITE BIGINT := 1;
  KICK_MEMBERS BIGINT := 2;
  BAN_MEMBERS BIGINT := 4;
  ADMINISTRATOR BIGINT := 8;
  MANAGE_CHANNELS BIGINT := 16;
  MANAGE_GUILD BIGINT := 32;
  ADD_REACTIONS BIGINT := 64;
  VIEW_AUDIT_LOG BIGINT := 128;
  PRIORITY_SPEAKER BIGINT := 256;
  STREAM BIGINT := 512;
  VIEW_CHANNEL BIGINT := 1024;
  SEND_MESSAGES BIGINT := 2048;
  SEND_TTS_MESSAGES BIGINT := 4096;
  MANAGE_MESSAGES BIGINT := 8192;
  EMBED_LINKS BIGINT := 16384;
  ATTACH_FILES BIGINT := 32768;
  READ_MESSAGE_HISTORY BIGINT := 65536;
  MENTION_EVERYONE BIGINT := 131072;
  USE_EXTERNAL_EMOJIS BIGINT := 262144;
  VIEW_GUILD_INSIGHTS BIGINT := 524288;
  CONNECT BIGINT := 1048576;
  SPEAK BIGINT := 2097152;
  MUTE_MEMBERS BIGINT := 4194304;
  DEAFEN_MEMBERS BIGINT := 8388608;
  MOVE_MEMBERS BIGINT := 16777216;
  USE_VAD BIGINT := 33554432;
  CHANGE_NICKNAME BIGINT := 67108864;
  MANAGE_NICKNAMES BIGINT := 134217728;
  MANAGE_ROLES BIGINT := 268435456;
  MANAGE_WEBHOOKS BIGINT := 536870912;
  MANAGE_EMOJIS_AND_STICKERS BIGINT := 1073741824;
  USE_APPLICATION_COMMANDS BIGINT := 2147483648;
  REQUEST_TO_SPEAK BIGINT := 4294967296;
  MANAGE_EVENTS BIGINT := 8589934592;
  MANAGE_THREADS BIGINT := 17179869184;
  CREATE_PUBLIC_THREADS BIGINT := 34359738368;
  CREATE_PRIVATE_THREADS BIGINT := 68719476736;
  USE_EXTERNAL_STICKERS BIGINT := 137438953472;
  SEND_MESSAGES_IN_THREADS BIGINT := 274877906944;
  USE_EMBEDDED_ACTIVITIES BIGINT := 549755813888;
  MODERATE_MEMBERS BIGINT := 1099511627776;
BEGIN
  CASE permission_name
    WHEN 'CREATE_INSTANT_INVITE' THEN RETURN CREATE_INSTANT_INVITE;
    WHEN 'KICK_MEMBERS' THEN RETURN KICK_MEMBERS;
    WHEN 'BAN_MEMBERS' THEN RETURN BAN_MEMBERS;
    WHEN 'ADMINISTRATOR' THEN RETURN ADMINISTRATOR;
    WHEN 'MANAGE_CHANNELS' THEN RETURN MANAGE_CHANNELS;
    WHEN 'MANAGE_GUILD' THEN RETURN MANAGE_GUILD;
    WHEN 'ADD_REACTIONS' THEN RETURN ADD_REACTIONS;
    WHEN 'VIEW_AUDIT_LOG' THEN RETURN VIEW_AUDIT_LOG;
    WHEN 'PRIORITY_SPEAKER' THEN RETURN PRIORITY_SPEAKER;
    WHEN 'STREAM' THEN RETURN STREAM;
    WHEN 'VIEW_CHANNEL' THEN RETURN VIEW_CHANNEL;
    WHEN 'SEND_MESSAGES' THEN RETURN SEND_MESSAGES;
    WHEN 'SEND_TTS_MESSAGES' THEN RETURN SEND_TTS_MESSAGES;
    WHEN 'MANAGE_MESSAGES' THEN RETURN MANAGE_MESSAGES;
    WHEN 'EMBED_LINKS' THEN RETURN EMBED_LINKS;
    WHEN 'ATTACH_FILES' THEN RETURN ATTACH_FILES;
    WHEN 'READ_MESSAGE_HISTORY' THEN RETURN READ_MESSAGE_HISTORY;
    WHEN 'MENTION_EVERYONE' THEN RETURN MENTION_EVERYONE;
    WHEN 'USE_EXTERNAL_EMOJIS' THEN RETURN USE_EXTERNAL_EMOJIS;
    WHEN 'VIEW_GUILD_INSIGHTS' THEN RETURN VIEW_GUILD_INSIGHTS;
    WHEN 'CONNECT' THEN RETURN CONNECT;
    WHEN 'SPEAK' THEN RETURN SPEAK;
    WHEN 'MUTE_MEMBERS' THEN RETURN MUTE_MEMBERS;
    WHEN 'DEAFEN_MEMBERS' THEN RETURN DEAFEN_MEMBERS;
    WHEN 'MOVE_MEMBERS' THEN RETURN MOVE_MEMBERS;
    WHEN 'USE_VAD' THEN RETURN USE_VAD;
    WHEN 'CHANGE_NICKNAME' THEN RETURN CHANGE_NICKNAME;
    WHEN 'MANAGE_NICKNAMES' THEN RETURN MANAGE_NICKNAMES;
    WHEN 'MANAGE_ROLES' THEN RETURN MANAGE_ROLES;
    WHEN 'MANAGE_WEBHOOKS' THEN RETURN MANAGE_WEBHOOKS;
    WHEN 'MANAGE_EMOJIS_AND_STICKERS' THEN RETURN MANAGE_EMOJIS_AND_STICKERS;
    WHEN 'USE_APPLICATION_COMMANDS' THEN RETURN USE_APPLICATION_COMMANDS;
    WHEN 'REQUEST_TO_SPEAK' THEN RETURN REQUEST_TO_SPEAK;
    WHEN 'MANAGE_EVENTS' THEN RETURN MANAGE_EVENTS;
    WHEN 'MANAGE_THREADS' THEN RETURN MANAGE_THREADS;
    WHEN 'CREATE_PUBLIC_THREADS' THEN RETURN CREATE_PUBLIC_THREADS;
    WHEN 'CREATE_PRIVATE_THREADS' THEN RETURN CREATE_PRIVATE_THREADS;
    WHEN 'USE_EXTERNAL_STICKERS' THEN RETURN USE_EXTERNAL_STICKERS;
    WHEN 'SEND_MESSAGES_IN_THREADS' THEN RETURN SEND_MESSAGES_IN_THREADS;
    WHEN 'USE_EMBEDDED_ACTIVITIES' THEN RETURN USE_EMBEDDED_ACTIVITIES;
    WHEN 'MODERATE_MEMBERS' THEN RETURN MODERATE_MEMBERS;
    ELSE RETURN 0;
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 1.18 Main permission calculation function
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

  -- 3. Calculate Base Permissions (from member_roles)
  -- Uses bitwise OR across all roles the user has in this server
  SELECT COALESCE(BIT_OR(r.permissions::bigint), 0)
  INTO base_permissions
  FROM public.member_roles mr
  JOIN public.roles r ON mr.role_id = r.id
  WHERE mr.user_id = target_user_uuid AND mr.server_id = target_server_uuid;

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
  JOIN public.member_roles mr ON po.target_id = mr.role_id
  WHERE po.channel_id = target_channel_uuid
    AND po.target_type = 'role'
    AND mr.user_id = target_user_uuid;

  base_permissions := (base_permissions & ~overwrite_deny) | overwrite_allow;

  -- 5b. User Specific Overwrites
  SELECT 
    COALESCE(po.allow, 0),
    COALESCE(po.deny, 0)
  INTO overwrite_allow, overwrite_deny
  FROM public.permission_overwrites po
  WHERE po.channel_id = target_channel_uuid
    AND po.target_type = 'user'
    AND po.target_id = target_user_uuid;

  -- 6. Calculate Final Permission
  final_permissions := (base_permissions & ~overwrite_deny) | overwrite_allow;

  -- 7. Return true if the requested permission bit is set in the final permissions
  RETURN (final_permissions & perm_bit) = perm_bit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
