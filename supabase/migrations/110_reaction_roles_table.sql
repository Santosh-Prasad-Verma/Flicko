-- ============================================
-- Migration 110: Reaction role mappings
-- ============================================
-- Story P3-E1-S1-T3

CREATE TABLE IF NOT EXISTS public.reaction_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL CHECK (char_length(trim(emoji)) > 0),
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (message_id, emoji),
  UNIQUE (server_id, channel_id, message_id, emoji, role_id)
);

CREATE INDEX IF NOT EXISTS idx_reaction_roles_server_id
  ON public.reaction_roles(server_id);
CREATE INDEX IF NOT EXISTS idx_reaction_roles_message_id
  ON public.reaction_roles(message_id);
CREATE INDEX IF NOT EXISTS idx_reaction_roles_role_id
  ON public.reaction_roles(role_id);

DROP TRIGGER IF EXISTS tr_reaction_roles_updated_at ON public.reaction_roles;
CREATE TRIGGER tr_reaction_roles_updated_at
  BEFORE UPDATE ON public.reaction_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.reaction_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read reaction roles for joined servers" ON public.reaction_roles;
CREATE POLICY "Users can read reaction roles for joined servers"
  ON public.reaction_roles FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = reaction_roles.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create reaction roles for joined servers" ON public.reaction_roles;
CREATE POLICY "Users can create reaction roles for joined servers"
  ON public.reaction_roles FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = reaction_roles.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update reaction roles for joined servers" ON public.reaction_roles;
CREATE POLICY "Users can update reaction roles for joined servers"
  ON public.reaction_roles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = reaction_roles.server_id
        AND sm.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = reaction_roles.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete reaction roles for joined servers" ON public.reaction_roles;
CREATE POLICY "Users can delete reaction roles for joined servers"
  ON public.reaction_roles FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = reaction_roles.server_id
        AND sm.user_id = auth.uid()
    )
  );
