-- ============================================
-- Migration 109: Account deletion jobs and audit log
-- ============================================
-- Story P2-E2-S2-T3

CREATE TABLE IF NOT EXISTS public.account_deletion_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'cancelled')),
  reason TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  scheduled_deletion_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  completed_at TIMESTAMPTZ,
  retention_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  error_message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_jobs_user_id
  ON public.account_deletion_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_account_deletion_jobs_user_status_requested
  ON public.account_deletion_jobs(user_id, status, requested_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_account_deletion_jobs_user_active
  ON public.account_deletion_jobs(user_id)
  WHERE status IN ('queued', 'processing');

DROP TRIGGER IF EXISTS tr_account_deletion_jobs_updated_at ON public.account_deletion_jobs;
CREATE TRIGGER tr_account_deletion_jobs_updated_at
  BEFORE UPDATE ON public.account_deletion_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.deletion_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.account_deletion_jobs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL
    CHECK (event_type IN ('requested', 'processing', 'completed', 'failed', 'cancelled')),
  event_message TEXT,
  event_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deletion_audit_log_job_id
  ON public.deletion_audit_log(job_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deletion_audit_log_user_id
  ON public.deletion_audit_log(user_id, created_at DESC);

ALTER TABLE public.account_deletion_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deletion_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own account deletion jobs" ON public.account_deletion_jobs;
CREATE POLICY "Users can read own account deletion jobs"
  ON public.account_deletion_jobs FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own account deletion jobs" ON public.account_deletion_jobs;
CREATE POLICY "Users can create own account deletion jobs"
  ON public.account_deletion_jobs FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own account deletion jobs" ON public.account_deletion_jobs;
CREATE POLICY "Users can update own account deletion jobs"
  ON public.account_deletion_jobs FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own account deletion jobs" ON public.account_deletion_jobs;
CREATE POLICY "Users can delete own account deletion jobs"
  ON public.account_deletion_jobs FOR DELETE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read own deletion audit log" ON public.deletion_audit_log;
CREATE POLICY "Users can read own deletion audit log"
  ON public.deletion_audit_log FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own deletion audit log" ON public.deletion_audit_log;
CREATE POLICY "Users can create own deletion audit log"
  ON public.deletion_audit_log FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users cannot update deletion audit log" ON public.deletion_audit_log;
CREATE POLICY "Users cannot update deletion audit log"
  ON public.deletion_audit_log FOR UPDATE
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS "Users cannot delete deletion audit log" ON public.deletion_audit_log;
CREATE POLICY "Users cannot delete deletion audit log"
  ON public.deletion_audit_log FOR DELETE
  USING (false);
