-- ============================================
-- Migration 121: Application install permissions
-- ============================================
-- Story P6-E1-S2-T2

CREATE TABLE IF NOT EXISTS public.application_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  install_id UUID NOT NULL REFERENCES public.application_installs(id) ON DELETE CASCADE,
  app_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  scope TEXT NOT NULL,
  allowed BOOLEAN NOT NULL DEFAULT true,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(install_id, scope)
);

CREATE INDEX IF NOT EXISTS idx_application_permissions_install
  ON public.application_permissions(install_id, allowed);
CREATE INDEX IF NOT EXISTS idx_application_permissions_server
  ON public.application_permissions(server_id, app_id);

DROP TRIGGER IF EXISTS tr_application_permissions_updated_at ON public.application_permissions;
CREATE TRIGGER tr_application_permissions_updated_at
  BEFORE UPDATE ON public.application_permissions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.application_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read permissions for joined-server installs" ON public.application_permissions;
CREATE POLICY "Users can read permissions for joined-server installs"
  ON public.application_permissions FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = application_permissions.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create install permissions they own" ON public.application_permissions;
CREATE POLICY "Users can create install permissions they own"
  ON public.application_permissions FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.application_installs ai
      WHERE ai.id = application_permissions.install_id
        AND ai.installed_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update install permissions they own" ON public.application_permissions;
CREATE POLICY "Users can update install permissions they own"
  ON public.application_permissions FOR UPDATE
  USING (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.application_installs ai
      WHERE ai.id = application_permissions.install_id
        AND ai.installed_by = auth.uid()
    )
  )
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.application_installs ai
      WHERE ai.id = application_permissions.install_id
        AND ai.installed_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete install permissions they own" ON public.application_permissions;
CREATE POLICY "Users can delete install permissions they own"
  ON public.application_permissions FOR DELETE
  USING (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.application_installs ai
      WHERE ai.id = application_permissions.install_id
        AND ai.installed_by = auth.uid()
    )
  );
