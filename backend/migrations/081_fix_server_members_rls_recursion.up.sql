-- Backend Up Migration 081: Fix server_members RLS Infinite Recursion
-- Creates is_server_member security definer helper and updates select policy.

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

DROP POLICY IF EXISTS "select_server_members" ON public.server_members;

CREATE POLICY "select_server_members" ON public.server_members FOR SELECT TO authenticated
USING (
  public.is_server_member(auth.uid(), server_id)
);
