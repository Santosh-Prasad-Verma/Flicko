-- Backend Down Migration 081: Restore old recursive server_members policy
-- Restores original select policy and drops helper function.

DROP POLICY IF EXISTS "select_server_members" ON public.server_members;

CREATE POLICY "select_server_members" ON public.server_members FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.server_members sm 
    WHERE sm.server_id = server_members.server_id 
      AND sm.user_id = auth.uid()
  )
);

DROP FUNCTION IF EXISTS public.is_server_member(uuid, uuid);
