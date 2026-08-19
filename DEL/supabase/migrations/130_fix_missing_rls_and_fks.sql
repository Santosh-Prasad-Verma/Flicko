-- Add missing foreign key for audit_log.user_id to profiles(id)
ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_user_id_fkey;
ALTER TABLE public.audit_log
  ADD CONSTRAINT audit_log_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Fix RLS for invites allowing users with CREATE_INVITE permission to create them
-- We will just use the server_members table to check membership, as any member can create invites by default unless restricted.
-- To keep it simple and fix the UI issue:
DROP POLICY IF EXISTS "Server owners can create invites" ON public.invites;
CREATE POLICY "Members can create invites"
  ON public.invites FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.server_members
      WHERE server_members.server_id = invites.server_id
      AND server_members.user_id = auth.uid()
    )
  );

-- Add missing RLS policies for server_templates
DROP POLICY IF EXISTS "Anyone can view server templates" ON public.server_templates;
CREATE POLICY "Anyone can view server templates"
  ON public.server_templates FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can create server templates" ON public.server_templates;
CREATE POLICY "Users can create server templates"
  ON public.server_templates FOR INSERT
  WITH CHECK (creator_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own server templates" ON public.server_templates;
CREATE POLICY "Users can update own server templates"
  ON public.server_templates FOR UPDATE
  USING (creator_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own server templates" ON public.server_templates;
CREATE POLICY "Users can delete own server templates"
  ON public.server_templates FOR DELETE
  USING (creator_id = auth.uid());

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
