-- 128_add_server_permission_function.sql

-- Helper function for server-level permission checks (without a specific channel context)
CREATE OR REPLACE FUNCTION public.has_server_permission(
  target_user_uuid UUID,
  target_server_uuid UUID,
  permission_name TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  is_owner BOOLEAN;
  base_permissions BIGINT := 0;
  perm_bit BIGINT;
BEGIN
  -- Get the permission bit we are checking for
  perm_bit := public.get_permission_bit(permission_name);
  IF perm_bit = 0 THEN
    RETURN FALSE; -- Invalid permission requested
  END IF;

  -- 1. Check if user is server owner (Owner has all permissions implicitly)
  SELECT owner_id = target_user_uuid INTO is_owner FROM public.servers WHERE id = target_server_uuid;
  IF is_owner THEN
    RETURN TRUE;
  END IF;

  -- 2. Calculate Base Permissions (from member_roles)
  -- Uses bitwise OR across all roles the user has in this server
  SELECT COALESCE(BIT_OR(r.permissions::bigint), 0)
  INTO base_permissions
  FROM public.member_roles mr
  JOIN public.roles r ON mr.role_id = r.id
  WHERE mr.user_id = target_user_uuid AND mr.server_id = target_server_uuid;

  -- 3. Check for ADMINISTRATOR permission
  IF (base_permissions & public.get_permission_bit('ADMINISTRATOR')) = public.get_permission_bit('ADMINISTRATOR') THEN
    RETURN TRUE;
  END IF;

  -- 4. Return true if the requested permission bit is set in the base permissions
  RETURN (base_permissions & perm_bit) = perm_bit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
