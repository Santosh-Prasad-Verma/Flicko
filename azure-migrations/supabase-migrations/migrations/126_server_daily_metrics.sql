-- ============================================
-- Migration 126: Server daily metrics rollups
-- ============================================
-- Story P8-E2-S1-T2

CREATE TABLE IF NOT EXISTS public.server_daily_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  metric_date DATE NOT NULL DEFAULT CURRENT_DATE,
  member_count INTEGER NOT NULL DEFAULT 0,
  new_members INTEGER NOT NULL DEFAULT 0,
  messages_sent INTEGER NOT NULL DEFAULT 0,
  active_members INTEGER NOT NULL DEFAULT 0,
  voice_active_members INTEGER NOT NULL DEFAULT 0,
  retention_members INTEGER NOT NULL DEFAULT 0,
  growth_rate NUMERIC(8,3) NOT NULL DEFAULT 0,
  engagement_rate NUMERIC(8,3) NOT NULL DEFAULT 0,
  retention_rate NUMERIC(8,3) NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(server_id, metric_date)
);

CREATE INDEX IF NOT EXISTS idx_server_daily_metrics_server_date
  ON public.server_daily_metrics(server_id, metric_date DESC);

DROP TRIGGER IF EXISTS tr_server_daily_metrics_updated_at ON public.server_daily_metrics;
CREATE TRIGGER tr_server_daily_metrics_updated_at
  BEFORE UPDATE ON public.server_daily_metrics
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.server_daily_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read metrics for joined servers" ON public.server_daily_metrics;
CREATE POLICY "Users can read metrics for joined servers"
  ON public.server_daily_metrics FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = server_daily_metrics.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Authenticated users can insert server metrics" ON public.server_daily_metrics;
CREATE POLICY "Authenticated users can insert server metrics"
  ON public.server_daily_metrics FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can update server metrics" ON public.server_daily_metrics;
CREATE POLICY "Authenticated users can update server metrics"
  ON public.server_daily_metrics FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can delete server metrics" ON public.server_daily_metrics;
CREATE POLICY "Authenticated users can delete server metrics"
  ON public.server_daily_metrics FOR DELETE
  USING (auth.uid() IS NOT NULL);
