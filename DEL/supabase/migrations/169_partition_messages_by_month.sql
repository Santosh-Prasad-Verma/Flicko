-- Migration 169: Monthly Message Partitioning & Management Triggers (RLS Hardened)

-- 1. Helper function to dynamically create monthly partitions for any given target date with RLS enabled
CREATE OR REPLACE FUNCTION public.create_message_partition_for_date(target_date TIMESTAMPTZ)
RETURNS TEXT AS $$
DECLARE
  partition_date DATE := date_trunc('month', target_date);
  start_str TEXT := to_char(partition_date, 'YYYY-MM-01');
  end_str TEXT := to_char(partition_date + INTERVAL '1 month', 'YYYY-MM-01');
  partition_name TEXT := 'messages_' || to_char(partition_date, 'YYYY_MM');
  sql_query TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = partition_name
  ) THEN
    sql_query := format(
      'CREATE TABLE IF NOT EXISTS public.%I (LIKE public.messages INCLUDING ALL); ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;',
      partition_name, partition_name
    );
    EXECUTE sql_query;
    RETURN partition_name;
  END IF;

  -- Ensure RLS is enabled even if table already existed
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', partition_name);
  RETURN partition_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Enable RLS on all existing messages_% partition tables
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT c.relname 
    FROM pg_class c 
    JOIN pg_namespace n ON n.oid = c.relnamespace 
    WHERE n.nspname = 'public' AND c.relname LIKE 'messages_%' AND c.relkind IN ('r', 'p')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.relname);
  END LOOP;
END $$;
