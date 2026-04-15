-- ============================================
-- Migration 123: App directory entries and reviews
-- ============================================
-- Story P6-E3-S1-T2

CREATE TABLE IF NOT EXISTS public.app_directory_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id UUID NOT NULL UNIQUE REFERENCES public.applications(id) ON DELETE CASCADE,
  category TEXT NOT NULL DEFAULT 'utility',
  short_description TEXT NOT NULL,
  long_description TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}',
  trust_score NUMERIC(5,2) NOT NULL DEFAULT 0
    CHECK (trust_score >= 0 AND trust_score <= 100),
  verified BOOLEAN NOT NULL DEFAULT false,
  moderated BOOLEAN NOT NULL DEFAULT false,
  is_listed BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_directory_entries_listing
  ON public.app_directory_entries(is_listed, verified, trust_score DESC);
CREATE INDEX IF NOT EXISTS idx_app_directory_entries_category
  ON public.app_directory_entries(category, is_listed);

DROP TRIGGER IF EXISTS tr_app_directory_entries_updated_at ON public.app_directory_entries;
CREATE TRIGGER tr_app_directory_entries_updated_at
  BEFORE UPDATE ON public.app_directory_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.app_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title TEXT,
  body TEXT,
  status TEXT NOT NULL DEFAULT 'published'
    CHECK (status IN ('published', 'hidden', 'flagged')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(app_id, reviewer_id)
);

CREATE INDEX IF NOT EXISTS idx_app_reviews_app_status
  ON public.app_reviews(app_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_reviews_reviewer
  ON public.app_reviews(reviewer_id, created_at DESC);

DROP TRIGGER IF EXISTS tr_app_reviews_updated_at ON public.app_reviews;
CREATE TRIGGER tr_app_reviews_updated_at
  BEFORE UPDATE ON public.app_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.app_directory_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read listed app directory entries" ON public.app_directory_entries;
CREATE POLICY "Users can read listed app directory entries"
  ON public.app_directory_entries FOR SELECT
  USING (is_listed = true);

DROP POLICY IF EXISTS "Owners can create app directory entries" ON public.app_directory_entries;
CREATE POLICY "Owners can create app directory entries"
  ON public.app_directory_entries FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = app_directory_entries.app_id
        AND a.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Owners can update app directory entries" ON public.app_directory_entries;
CREATE POLICY "Owners can update app directory entries"
  ON public.app_directory_entries FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = app_directory_entries.app_id
        AND a.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = app_directory_entries.app_id
        AND a.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Owners can delete app directory entries" ON public.app_directory_entries;
CREATE POLICY "Owners can delete app directory entries"
  ON public.app_directory_entries FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.applications a
      WHERE a.id = app_directory_entries.app_id
        AND a.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can read published app reviews" ON public.app_reviews;
CREATE POLICY "Users can read published app reviews"
  ON public.app_reviews FOR SELECT
  USING (status = 'published');

DROP POLICY IF EXISTS "Users can create own app reviews" ON public.app_reviews;
CREATE POLICY "Users can create own app reviews"
  ON public.app_reviews FOR INSERT
  WITH CHECK (reviewer_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own app reviews" ON public.app_reviews;
CREATE POLICY "Users can update own app reviews"
  ON public.app_reviews FOR UPDATE
  USING (reviewer_id = auth.uid())
  WITH CHECK (reviewer_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own app reviews" ON public.app_reviews;
CREATE POLICY "Users can delete own app reviews"
  ON public.app_reviews FOR DELETE
  USING (reviewer_id = auth.uid());
