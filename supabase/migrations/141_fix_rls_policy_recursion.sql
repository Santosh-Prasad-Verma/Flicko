-- Migration: Fix infinite recursion in RLS policies for server_members, channels, roles, and server_perks.
-- The previous 'ALL' policies on these tables executed subqueries referencing the 'servers' table,
-- which recursively queried 'server_members' or other tables, leading to infinite recursion.
-- We split them into separate INSERT, UPDATE, and DELETE policies to avoid evaluating them on SELECT.

-- 1. Fix server_members RLS policy recursion
DROP POLICY IF EXISTS "manage_members_as_owner" ON public.server_members;

CREATE POLICY "manage_members_as_owner_insert" ON public.server_members
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = server_members.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_members_as_owner_update" ON public.server_members
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = server_members.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_members_as_owner_delete" ON public.server_members
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = server_members.server_id
      AND servers.owner_id = auth.uid()
    )
  );

-- 2. Fix channels RLS policy recursion
DROP POLICY IF EXISTS "manage_channels" ON public.channels;

CREATE POLICY "manage_channels_insert" ON public.channels
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = channels.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_channels_update" ON public.channels
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = channels.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_channels_delete" ON public.channels
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = channels.server_id
      AND servers.owner_id = auth.uid()
    )
  );

-- 3. Fix roles RLS policy recursion
DROP POLICY IF EXISTS "manage_roles" ON public.roles;

CREATE POLICY "manage_roles_insert" ON public.roles
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = roles.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_roles_update" ON public.roles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = roles.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_roles_delete" ON public.roles
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = roles.server_id
      AND servers.owner_id = auth.uid()
    )
  );

-- 4. Fix server_perks RLS policy recursion
DROP POLICY IF EXISTS "manage_server_perks" ON public.server_perks;

CREATE POLICY "manage_server_perks_insert" ON public.server_perks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = server_perks.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_server_perks_update" ON public.server_perks
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = server_perks.server_id
      AND servers.owner_id = auth.uid()
    )
  );

CREATE POLICY "manage_server_perks_delete" ON public.server_perks
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.servers
      WHERE servers.id = server_perks.server_id
      AND servers.owner_id = auth.uid()
    )
  );
