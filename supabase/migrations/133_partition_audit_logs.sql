-- 133_partition_audit_logs.sql

-- 1. Rename existing audit_logs table
ALTER TABLE IF EXISTS public.audit_logs RENAME TO audit_logs_old;

-- 2. Drop old indexes explicitly if they were not dropped by rename
DROP INDEX IF EXISTS public.idx_audit_logs_server_id;
DROP INDEX IF EXISTS public.idx_audit_logs_actor_id;
DROP INDEX IF EXISTS public.idx_audit_logs_action_type;
DROP INDEX IF EXISTS public.idx_audit_logs_target_id;

-- 3. Create the new partitioned parent table
CREATE TABLE public.audit_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id UUID,
  reason TEXT,
  changes JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- 4. Create monthly partitions
CREATE TABLE public.audit_logs_y2026m05 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-05-01 00:00:00+00') TO ('2026-06-01 00:00:00+00');

CREATE TABLE public.audit_logs_y2026m06 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');

CREATE TABLE public.audit_logs_y2026m07 PARTITION OF public.audit_logs
  FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');

-- 5. Create default partition to catch any outlier dates safely
CREATE TABLE public.audit_logs_default PARTITION OF public.audit_logs DEFAULT;

-- 6. Migrate data from old table to new partitioned table if old table existed
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'audit_logs_old') THEN
    INSERT INTO public.audit_logs (id, server_id, actor_id, action_type, target_type, target_id, reason, changes, created_at)
    SELECT id, server_id, actor_id, action_type, target_type, target_id, reason, changes, created_at FROM public.audit_logs_old;
    
    DROP TABLE public.audit_logs_old;
  END IF;
END $$;

-- 7. Create indexes on parent partitioned table (applies recursively to all partitions)
CREATE INDEX idx_audit_logs_server_id ON public.audit_logs(server_id);
CREATE INDEX idx_audit_logs_actor_id ON public.audit_logs(actor_id);
CREATE INDEX idx_audit_logs_action_type ON public.audit_logs(action_type);
CREATE INDEX idx_audit_logs_target_id ON public.audit_logs(target_id);
