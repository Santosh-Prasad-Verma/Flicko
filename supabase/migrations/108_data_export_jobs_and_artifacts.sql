-- ============================================
-- Migration 108: Data export jobs and artifacts
-- ============================================
-- Story P2-E2-S1-T3

CREATE TABLE IF NOT EXISTS public.data_export_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  format TEXT NOT NULL DEFAULT 'json' CHECK (format IN ('json')),
  status TEXT NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'expired', 'cancelled')),
  progress_percent INTEGER NOT NULL DEFAULT 0 CHECK (progress_percent >= 0 AND progress_percent <= 100),
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  error_message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_data_export_jobs_user_id ON public.data_export_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_data_export_jobs_user_status_requested
  ON public.data_export_jobs(user_id, status, requested_at DESC);

DROP TRIGGER IF EXISTS tr_data_export_jobs_updated_at ON public.data_export_jobs;
CREATE TRIGGER tr_data_export_jobs_updated_at
  BEFORE UPDATE ON public.data_export_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.data_export_artifacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.data_export_jobs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  storage_path TEXT,
  file_name TEXT,
  content_type TEXT,
  file_size_bytes BIGINT,
  checksum TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'ready', 'failed', 'expired', 'deleted')),
  retention_until TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_data_export_artifacts_job_id ON public.data_export_artifacts(job_id);
CREATE INDEX IF NOT EXISTS idx_data_export_artifacts_user_status
  ON public.data_export_artifacts(user_id, status, created_at DESC);

DROP TRIGGER IF EXISTS tr_data_export_artifacts_updated_at ON public.data_export_artifacts;
CREATE TRIGGER tr_data_export_artifacts_updated_at
  BEFORE UPDATE ON public.data_export_artifacts
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.data_export_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_export_artifacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own data export jobs" ON public.data_export_jobs;
CREATE POLICY "Users can read own data export jobs"
  ON public.data_export_jobs FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own data export jobs" ON public.data_export_jobs;
CREATE POLICY "Users can create own data export jobs"
  ON public.data_export_jobs FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own data export jobs" ON public.data_export_jobs;
CREATE POLICY "Users can update own data export jobs"
  ON public.data_export_jobs FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own data export jobs" ON public.data_export_jobs;
CREATE POLICY "Users can delete own data export jobs"
  ON public.data_export_jobs FOR DELETE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read own data export artifacts" ON public.data_export_artifacts;
CREATE POLICY "Users can read own data export artifacts"
  ON public.data_export_artifacts FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own data export artifacts" ON public.data_export_artifacts;
CREATE POLICY "Users can create own data export artifacts"
  ON public.data_export_artifacts FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own data export artifacts" ON public.data_export_artifacts;
CREATE POLICY "Users can update own data export artifacts"
  ON public.data_export_artifacts FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own data export artifacts" ON public.data_export_artifacts;
CREATE POLICY "Users can delete own data export artifacts"
  ON public.data_export_artifacts FOR DELETE
  USING (user_id = auth.uid());
