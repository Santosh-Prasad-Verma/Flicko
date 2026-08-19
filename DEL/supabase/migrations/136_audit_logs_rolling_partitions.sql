-- HIGH-20: Auto-create monthly audit_logs partitions for the next 12 months
-- and a sweeper that creates the upcoming partition on a daily schedule.
-- Without this, all audit rows for any month past July 2026 land in the
-- audit_logs_default partition and operationally degrade the table.

-- 1. Function: ensure a partition exists for the YYYY-MM that contains the
--    given timestamp. Idempotent.
CREATE OR REPLACE FUNCTION public.ensure_audit_logs_partition(target_date TIMESTAMPTZ)
RETURNS VOID AS $$
DECLARE
  partition_name TEXT;
  range_start    TIMESTAMPTZ;
  range_end      TIMESTAMPTZ;
BEGIN
  range_start := date_trunc('month', target_date);
  range_end   := range_start + INTERVAL '1 month';
  partition_name := 'audit_logs_y' || to_char(range_start, 'YYYY') || 'm' || to_char(range_start, 'MM');

  -- Skip if it already exists.
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = partition_name AND n.nspname = 'public'
  ) THEN
    EXECUTE format(
      'CREATE TABLE public.%I PARTITION OF public.audit_logs FOR VALUES FROM (%L) TO (%L)',
      partition_name, range_start, range_end
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. Function: ensure partitions for the current month and the next 12 months
--    exist. Designed to be called by pg_cron daily.
CREATE OR REPLACE FUNCTION public.ensure_audit_logs_partitions_ahead()
RETURNS VOID AS $$
DECLARE
  i INT;
BEGIN
  FOR i IN 0..12 LOOP
    PERFORM public.ensure_audit_logs_partition(NOW() + (i || ' months')::INTERVAL);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Run once now so the next 13 months are pre-created.
SELECT public.ensure_audit_logs_partitions_ahead();

-- 4. Schedule via pg_cron if available. If pg_cron isn't installed, this
--    falls through silently — operators should run a daily cron externally.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'audit-logs-partition-maintainer',
      '15 3 * * *',  -- daily at 03:15 UTC
      $cron$SELECT public.ensure_audit_logs_partitions_ahead();$cron$
    );
  END IF;
END $$;
