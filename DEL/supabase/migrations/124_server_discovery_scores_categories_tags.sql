-- ============================================
-- Migration 124: Server discovery ranking taxonomy
-- ============================================
-- Story P8-E1-S1-T2

CREATE TABLE IF NOT EXISTS public.server_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS tr_server_categories_updated_at ON public.server_categories;
CREATE TRIGGER tr_server_categories_updated_at
  BEFORE UPDATE ON public.server_categories
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.server_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(server_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_server_tags_server
  ON public.server_tags(server_id);
CREATE INDEX IF NOT EXISTS idx_server_tags_tag
  ON public.server_tags(tag);

CREATE TABLE IF NOT EXISTS public.server_discovery_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.server_categories(id) ON DELETE SET NULL,
  score_date DATE NOT NULL DEFAULT CURRENT_DATE,
  composite_score NUMERIC(8,3) NOT NULL DEFAULT 0,
  growth_score NUMERIC(8,3) NOT NULL DEFAULT 0,
  engagement_score NUMERIC(8,3) NOT NULL DEFAULT 0,
  retention_score NUMERIC(8,3) NOT NULL DEFAULT 0,
  trust_score NUMERIC(8,3) NOT NULL DEFAULT 0,
  reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(server_id, score_date)
);

CREATE INDEX IF NOT EXISTS idx_server_discovery_scores_rank
  ON public.server_discovery_scores(score_date DESC, composite_score DESC);
CREATE INDEX IF NOT EXISTS idx_server_discovery_scores_server
  ON public.server_discovery_scores(server_id, score_date DESC);
CREATE INDEX IF NOT EXISTS idx_server_discovery_scores_category
  ON public.server_discovery_scores(category_id, score_date DESC, composite_score DESC);

DROP TRIGGER IF EXISTS tr_server_discovery_scores_updated_at ON public.server_discovery_scores;
CREATE TRIGGER tr_server_discovery_scores_updated_at
  BEFORE UPDATE ON public.server_discovery_scores
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.server_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.server_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.server_discovery_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read active server categories" ON public.server_categories;
CREATE POLICY "Anyone can read active server categories"
  ON public.server_categories FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "Authenticated users can insert server categories" ON public.server_categories;
CREATE POLICY "Authenticated users can insert server categories"
  ON public.server_categories FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can update server categories" ON public.server_categories;
CREATE POLICY "Authenticated users can update server categories"
  ON public.server_categories FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can delete server categories" ON public.server_categories;
CREATE POLICY "Authenticated users can delete server categories"
  ON public.server_categories FOR DELETE
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can read tags for public or joined servers" ON public.server_tags;
CREATE POLICY "Users can read tags for public or joined servers"
  ON public.server_tags FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.servers s
      WHERE s.id = server_tags.server_id
        AND 'DISCOVERABLE' = ANY(s.features)
    )
    OR EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = server_tags.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can create tags for joined servers" ON public.server_tags;
CREATE POLICY "Users can create tags for joined servers"
  ON public.server_tags FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = server_tags.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update own server tags" ON public.server_tags;
CREATE POLICY "Users can update own server tags"
  ON public.server_tags FOR UPDATE
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "Users can delete own server tags" ON public.server_tags;
CREATE POLICY "Users can delete own server tags"
  ON public.server_tags FOR DELETE
  USING (created_by = auth.uid());

DROP POLICY IF EXISTS "Users can read discovery scores for public or joined servers" ON public.server_discovery_scores;
CREATE POLICY "Users can read discovery scores for public or joined servers"
  ON public.server_discovery_scores FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.servers s
      WHERE s.id = server_discovery_scores.server_id
        AND 'DISCOVERABLE' = ANY(s.features)
    )
    OR EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = server_discovery_scores.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Authenticated users can insert discovery scores" ON public.server_discovery_scores;
CREATE POLICY "Authenticated users can insert discovery scores"
  ON public.server_discovery_scores FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can update discovery scores" ON public.server_discovery_scores;
CREATE POLICY "Authenticated users can update discovery scores"
  ON public.server_discovery_scores FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can delete discovery scores" ON public.server_discovery_scores;
CREATE POLICY "Authenticated users can delete discovery scores"
  ON public.server_discovery_scores FOR DELETE
  USING (auth.uid() IS NOT NULL);

INSERT INTO public.server_categories (slug, name, description, is_active)
VALUES
  ('gaming', 'Gaming', 'Communities focused on multiplayer games and esports.', true),
  ('education', 'Education', 'Learning communities, study groups, and mentorship.', true),
  ('music', 'Music', 'Music sharing, production, fandoms, and live sessions.', true),
  ('tech', 'Technology', 'Programming, startups, AI, and software communities.', true),
  ('social', 'Social', 'General social and interest-based hangout communities.', true)
ON CONFLICT (slug) DO NOTHING;
