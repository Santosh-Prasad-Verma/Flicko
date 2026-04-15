-- ============================================
-- Migration 112: Purge jobs and audit metadata
-- ============================================
-- Story P3-E2-S1-T2

CREATE TABLE IF NOT EXISTS public.purge_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  requested_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'cancelled')),
  requested_count INTEGER NOT NULL CHECK (requested_count BETWEEN 1 AND 100),
  deleted_count INTEGER NOT NULL DEFAULT 0 CHECK (deleted_count >= 0),
  reason TEXT,
  audit_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_purge_jobs_server_id
  ON public.purge_jobs(server_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_purge_jobs_channel_id
  ON public.purge_jobs(channel_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_purge_jobs_requested_by
  ON public.purge_jobs(requested_by, requested_at DESC);

DROP TRIGGER IF EXISTS tr_purge_jobs_updated_at ON public.purge_jobs;
CREATE TRIGGER tr_purge_jobs_updated_at
  BEFORE UPDATE ON public.purge_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.purge_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read purge jobs for joined servers" ON public.purge_jobs;
CREATE POLICY "Users can read purge jobs for joined servers"
  ON public.purge_jobs FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = purge_jobs.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create purge jobs for joined servers" ON public.purge_jobs;
CREATE POLICY "Users can create purge jobs for joined servers"
  ON public.purge_jobs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = purge_jobs.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update purge jobs they requested" ON public.purge_jobs;
CREATE POLICY "Users can update purge jobs they requested"
  ON public.purge_jobs FOR UPDATE
  USING (requested_by = auth.uid())
  WITH CHECK (requested_by = auth.uid());

DROP POLICY IF EXISTS "Users can delete purge jobs they requested" ON public.purge_jobs;
CREATE POLICY "Users can delete purge jobs they requested"
  ON public.purge_jobs FOR DELETE
  USING (requested_by = auth.uid());
