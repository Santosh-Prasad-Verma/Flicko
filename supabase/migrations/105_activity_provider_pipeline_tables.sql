-- ============================================
-- Migration 105: Activity provider pipeline
-- ============================================
-- Story P1-E3-S2-T3: Add provider pipeline tables

CREATE OR REPLACE FUNCTION public.activity_provider_slug(provider_name TEXT, provider_id UUID)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  WITH normalized AS (
    SELECT regexp_replace(lower(COALESCE(provider_name, 'provider')), '[^a-z0-9]+', '-', 'g') AS base_slug
  )
  SELECT
    trim(both '-' FROM regexp_replace(normalized.base_slug, '-{2,}', '-', 'g'))
    || '-'
    || substr(replace(provider_id::text, '-', ''), 1, 8)
  FROM normalized;
$$;

CREATE OR REPLACE FUNCTION public.ensure_activity_provider_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.slug IS NULL OR length(trim(NEW.slug)) = 0 THEN
    NEW.slug := public.activity_provider_slug(NEW.name, NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.activity_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  description TEXT,
  homepage_url TEXT,
  integration_url TEXT,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'pending_review', 'approved', 'rejected', 'published', 'disabled')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  mobile_supported BOOLEAN NOT NULL DEFAULT true,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'activity_providers_slug_not_blank'
      AND conrelid = 'public.activity_providers'::regclass
  ) THEN
    ALTER TABLE public.activity_providers
      ADD CONSTRAINT activity_providers_slug_not_blank CHECK (slug IS NULL OR length(trim(slug)) > 0);
  END IF;
END
$$;

UPDATE public.activity_providers p
SET slug = public.activity_provider_slug(p.name, p.id)
WHERE p.slug IS NULL;

ALTER TABLE public.activity_providers
  ALTER COLUMN slug SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_activity_providers_owner ON public.activity_providers(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_activity_providers_status ON public.activity_providers(status);

DROP TRIGGER IF EXISTS tr_activity_providers_ensure_slug ON public.activity_providers;
CREATE TRIGGER tr_activity_providers_ensure_slug
  BEFORE INSERT OR UPDATE ON public.activity_providers
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_activity_provider_slug();

DROP TRIGGER IF EXISTS tr_activity_providers_updated_at ON public.activity_providers;
CREATE TRIGGER tr_activity_providers_updated_at
  BEFORE UPDATE ON public.activity_providers
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.activity_provider_secrets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.activity_providers(id) ON DELETE CASCADE,
  secret_key TEXT NOT NULL,
  secret_value TEXT NOT NULL,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider_id, secret_key)
);

CREATE INDEX IF NOT EXISTS idx_activity_provider_secrets_provider ON public.activity_provider_secrets(provider_id);

DROP TRIGGER IF EXISTS tr_activity_provider_secrets_updated_at ON public.activity_provider_secrets;
CREATE TRIGGER tr_activity_provider_secrets_updated_at
  BEFORE UPDATE ON public.activity_provider_secrets
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.activity_review_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL REFERENCES public.activity_providers(id) ON DELETE CASCADE,
  submitted_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reviewer_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  review_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_activity_review_queue_provider ON public.activity_review_queue(provider_id);
CREATE INDEX IF NOT EXISTS idx_activity_review_queue_status ON public.activity_review_queue(status);

DROP TRIGGER IF EXISTS tr_activity_review_queue_updated_at ON public.activity_review_queue;
CREATE TRIGGER tr_activity_review_queue_updated_at
  BEFORE UPDATE ON public.activity_review_queue
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.activity_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_provider_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_review_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own or published activity providers" ON public.activity_providers;
CREATE POLICY "Users can read own or published activity providers"
  ON public.activity_providers FOR SELECT
  USING (
    owner_user_id = auth.uid()
    OR status = 'published'
  );

DROP POLICY IF EXISTS "Users can create own activity providers" ON public.activity_providers;
CREATE POLICY "Users can create own activity providers"
  ON public.activity_providers FOR INSERT
  WITH CHECK (owner_user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own activity providers" ON public.activity_providers;
CREATE POLICY "Users can update own activity providers"
  ON public.activity_providers FOR UPDATE
  USING (owner_user_id = auth.uid())
  WITH CHECK (owner_user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own activity providers" ON public.activity_providers;
CREATE POLICY "Users can delete own activity providers"
  ON public.activity_providers FOR DELETE
  USING (owner_user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read provider secrets for owned providers" ON public.activity_provider_secrets;
CREATE POLICY "Users can read provider secrets for owned providers"
  ON public.activity_provider_secrets FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.activity_providers p
      WHERE p.id = activity_provider_secrets.provider_id
        AND p.owner_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert provider secrets for owned providers" ON public.activity_provider_secrets;
CREATE POLICY "Users can insert provider secrets for owned providers"
  ON public.activity_provider_secrets FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.activity_providers p
      WHERE p.id = activity_provider_secrets.provider_id
        AND p.owner_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update provider secrets for owned providers" ON public.activity_provider_secrets;
CREATE POLICY "Users can update provider secrets for owned providers"
  ON public.activity_provider_secrets FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.activity_providers p
      WHERE p.id = activity_provider_secrets.provider_id
        AND p.owner_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.activity_providers p
      WHERE p.id = activity_provider_secrets.provider_id
        AND p.owner_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete provider secrets for owned providers" ON public.activity_provider_secrets;
CREATE POLICY "Users can delete provider secrets for owned providers"
  ON public.activity_provider_secrets FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.activity_providers p
      WHERE p.id = activity_provider_secrets.provider_id
        AND p.owner_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can read review queue for owned providers" ON public.activity_review_queue;
CREATE POLICY "Users can read review queue for owned providers"
  ON public.activity_review_queue FOR SELECT
  USING (
    submitted_by = auth.uid()
    OR reviewer_user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.activity_providers p
      WHERE p.id = activity_review_queue.provider_id
        AND p.owner_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can enqueue review for owned providers" ON public.activity_review_queue;
CREATE POLICY "Users can enqueue review for owned providers"
  ON public.activity_review_queue FOR INSERT
  WITH CHECK (
    submitted_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.activity_providers p
      WHERE p.id = activity_review_queue.provider_id
        AND p.owner_user_id = auth.uid()
    )
  );
