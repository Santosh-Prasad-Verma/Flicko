-- Allow profile role badges to read assigned roles from the canonical member_roles table.

ALTER TABLE public.member_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view shared member roles" ON public.member_roles;

CREATE POLICY "Members can view shared member roles"
  ON public.member_roles
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = member_roles.server_id
        AND sm.user_id = auth.uid()
    )
  );
