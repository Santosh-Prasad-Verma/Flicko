-- ============================================
-- Migration 104: Activities catalog metadata
-- ============================================
-- Story P1-E3-S1-T3: Add activities_catalog

CREATE TABLE IF NOT EXISTS public.activities_catalog (
  activity_id UUID PRIMARY KEY REFERENCES public.activities(id) ON DELETE CASCADE,
  slug TEXT NOT NULL UNIQUE,
  provider TEXT NOT NULL DEFAULT 'flicko',
  capabilities JSONB NOT NULL DEFAULT '[]'::jsonb,
  mobile_supported BOOLEAN NOT NULL DEFAULT true,
  enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activities_catalog_provider
  ON public.activities_catalog(provider);

CREATE INDEX IF NOT EXISTS idx_activities_catalog_enabled
  ON public.activities_catalog(enabled);

DROP TRIGGER IF EXISTS tr_activities_catalog_updated_at ON public.activities_catalog;
CREATE TRIGGER tr_activities_catalog_updated_at
  BEFORE UPDATE ON public.activities_catalog
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.activities_catalog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view activities catalog metadata"
  ON public.activities_catalog FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can insert activities catalog metadata"
  ON public.activities_catalog FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update activities catalog metadata"
  ON public.activities_catalog FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE OR REPLACE FUNCTION public.catalog_activity_slug(activity_name TEXT, activity_id UUID)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  WITH normalized AS (
    SELECT regexp_replace(lower(COALESCE(activity_name, 'activity')), '[^a-z0-9]+', '-', 'g') AS base_slug
  )
  SELECT
    trim(both '-' FROM regexp_replace(base_slug, '-{2,}', '-', 'g'))
    || '-'
    || substr(replace(activity_id::text, '-', ''), 1, 8);
$$;

-- Backfill entries for existing catalog activities where missing.
INSERT INTO public.activities_catalog (activity_id, slug, provider, capabilities, mobile_supported, enabled)
SELECT
  a.id,
  public.catalog_activity_slug(a.name, a.id),
  'flicko',
  '[]'::jsonb,
  true,
  COALESCE(a.enabled, true)
FROM public.activities a
WHERE a.user_id IS NULL
  AND COALESCE(a.enabled, true) = true
ON CONFLICT (activity_id) DO NOTHING;
