-- ============================================
-- Migration 120: Applications, installs, and scopes
-- ============================================
-- Story P6-E1-S1-T3

CREATE TABLE IF NOT EXISTS public.applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  is_public BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_applications_owner
  ON public.applications(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_applications_public_active
  ON public.applications(is_public, is_active);

DROP TRIGGER IF EXISTS tr_applications_updated_at ON public.applications;
CREATE TRIGGER tr_applications_updated_at
  BEFORE UPDATE ON public.applications
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.application_scopes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  scope TEXT NOT NULL,
  description TEXT,
  is_required BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(app_id, scope)
);

CREATE INDEX IF NOT EXISTS idx_application_scopes_app
  ON public.application_scopes(app_id);

CREATE TABLE IF NOT EXISTS public.application_installs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  installed_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'revoked')),
  granted_scopes TEXT[] NOT NULL DEFAULT '{}',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(app_id, server_id)
);

CREATE INDEX IF NOT EXISTS idx_application_installs_server
  ON public.application_installs(server_id, status, installed_at DESC);
CREATE INDEX IF NOT EXISTS idx_application_installs_app
  ON public.application_installs(app_id, status, installed_at DESC);

DROP TRIGGER IF EXISTS tr_application_installs_updated_at ON public.application_installs;
CREATE TRIGGER tr_application_installs_updated_at
  BEFORE UPDATE ON public.application_installs
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_scopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_installs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read public or owned applications" ON public.applications;
CREATE POLICY "Users can read public or owned applications"
  ON public.applications FOR SELECT
  USING (is_public = true OR owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own applications" ON public.applications;
CREATE POLICY "Users can create own applications"
  ON public.applications FOR INSERT
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own applications" ON public.applications;
CREATE POLICY "Users can update own applications"
  ON public.applications FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own applications" ON public.applications;
CREATE POLICY "Users can delete own applications"
  ON public.applications FOR DELETE
  USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "Users can read scopes for visible applications" ON public.application_scopes;
CREATE POLICY "Users can read scopes for visible applications"
  ON public.application_scopes FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = application_scopes.app_id
        AND (a.is_public = true OR a.owner_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create scopes for own applications" ON public.application_scopes;
CREATE POLICY "Users can create scopes for own applications"
  ON public.application_scopes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = application_scopes.app_id
        AND a.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update scopes for own applications" ON public.application_scopes;
CREATE POLICY "Users can update scopes for own applications"
  ON public.application_scopes FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = application_scopes.app_id
        AND a.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = application_scopes.app_id
        AND a.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete scopes for own applications" ON public.application_scopes;
CREATE POLICY "Users can delete scopes for own applications"
  ON public.application_scopes FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = application_scopes.app_id
        AND a.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can read own or joined-server installs" ON public.application_installs;
CREATE POLICY "Users can read own or joined-server installs"
  ON public.application_installs FOR SELECT
  USING (
    installed_by = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = application_installs.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create installs for own user" ON public.application_installs;
CREATE POLICY "Users can create installs for own user"
  ON public.application_installs FOR INSERT
  WITH CHECK (installed_by = auth.uid());

DROP POLICY IF EXISTS "Users can update installs they created" ON public.application_installs;
CREATE POLICY "Users can update installs they created"
  ON public.application_installs FOR UPDATE
  USING (installed_by = auth.uid())
  WITH CHECK (installed_by = auth.uid());

DROP POLICY IF EXISTS "Users can delete installs they created" ON public.application_installs;
CREATE POLICY "Users can delete installs they created"
  ON public.application_installs FOR DELETE
  USING (installed_by = auth.uid());
