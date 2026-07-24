-- Migration 159: Definitive fix for server_members RLS infinite recursion
--
-- ROOT CAUSE:
-- Migration 150 created a "manage_server_members" policy with FOR ALL,
-- which also applies to SELECT operations. Its USING clause calls
-- has_server_permission() → queries member_roles → joins roles → the
-- "select_roles" policy queries server_members → infinite recursion.
--
-- FIX:
-- 1. Drop the FOR ALL policy.
-- 2. Recreate it as separate INSERT, UPDATE, DELETE policies (not SELECT).
-- 3. Also drop and recreate "manage_members_as_owner_*" from migration 141
--    to consolidate into clean, non-overlapping policies.
-- 4. Ensure the SELECT policy from migration 155 (using SECURITY DEFINER
--    is_server_member function) remains the ONLY select policy.

-- ============================================================
-- Step 1: Drop ALL existing conflicting policies on server_members
-- ============================================================
DROP POLICY IF EXISTS "manage_server_members" ON public.server_members;
DROP POLICY IF EXISTS "insert_server_members" ON public.server_members;
DROP POLICY IF EXISTS "manage_members_as_owner_insert" ON public.server_members;
DROP POLICY IF EXISTS "manage_members_as_owner_update" ON public.server_members;
DROP POLICY IF EXISTS "manage_members_as_owner_delete" ON public.server_members;

-- Also re-drop + recreate select_server_members to guarantee it uses the
-- SECURITY DEFINER helper and is the only SELECT policy.
DROP POLICY IF EXISTS "select_server_members" ON public.server_members;

-- ============================================================
-- Step 2: Ensure the SECURITY DEFINER helper exists
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_server_member(target_user_id uuid, target_server_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.server_members
    WHERE server_id = target_server_id AND user_id = target_user_id
  );
END;
$$;

-- ============================================================
-- Step 3: Create clean, non-recursive policies
-- ============================================================

-- SELECT: uses SECURITY DEFINER to bypass RLS on the self-reference
CREATE POLICY "select_server_members" ON public.server_members
  FOR SELECT TO authenticated
  USING (public.is_server_member(auth.uid(), server_id));

-- INSERT: user can add themselves, or server owner, or MANAGE_MEMBERS permission
CREATE POLICY "insert_server_members" ON public.server_members
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
    )
    OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_MEMBERS')
  );

-- UPDATE: user can update own row, or server owner, or MANAGE_MEMBERS permission
CREATE POLICY "update_server_members" ON public.server_members
  FOR UPDATE TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
    )
    OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_MEMBERS')
  );

-- DELETE: user can remove themselves, or server owner, or MANAGE_MEMBERS permission
CREATE POLICY "delete_server_members" ON public.server_members
  FOR DELETE TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
    )
    OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_MEMBERS')
  );

-- ============================================================
-- Step 4: Also fix the roles SELECT policy which queries server_members
-- and can trigger recursion from other tables.
-- Use the same SECURITY DEFINER helper.
-- ============================================================
DROP POLICY IF EXISTS "select_roles" ON public.roles;

CREATE POLICY "select_roles" ON public.roles
  FOR SELECT TO authenticated
  USING (public.is_server_member(auth.uid(), server_id));

-- ============================================================
-- Step 5: Fix channels SELECT policy (same pattern)
-- ============================================================
DROP POLICY IF EXISTS "select_channels" ON public.channels;

CREATE POLICY "select_channels" ON public.channels
  FOR SELECT TO authenticated
  USING (public.is_server_member(auth.uid(), server_id));
