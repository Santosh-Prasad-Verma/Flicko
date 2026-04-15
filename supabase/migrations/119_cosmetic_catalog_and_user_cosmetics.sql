-- ============================================
-- Migration 119: Cosmetic catalog and user cosmetics
-- ============================================
-- Story P5-E1-S3-T3

CREATE TABLE IF NOT EXISTS public.cosmetic_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  cosmetic_type TEXT NOT NULL
    CHECK (cosmetic_type IN ('avatar_decoration', 'profile_effect', 'nameplate')),
  asset_url TEXT NOT NULL,
  rarity TEXT NOT NULL DEFAULT 'common'
    CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
  required_plan TEXT
    CHECK (required_plan IN ('nitro_basic', 'nitro_full')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cosmetic_catalog_type_active
  ON public.cosmetic_catalog(cosmetic_type, is_active);

DROP TRIGGER IF EXISTS tr_cosmetic_catalog_updated_at ON public.cosmetic_catalog;
CREATE TRIGGER tr_cosmetic_catalog_updated_at
  BEFORE UPDATE ON public.cosmetic_catalog
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.user_cosmetics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cosmetic_id UUID NOT NULL REFERENCES public.cosmetic_catalog(id) ON DELETE CASCADE,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source TEXT NOT NULL DEFAULT 'subscription'
    CHECK (source IN ('subscription', 'gift', 'purchase', 'grant')),
  is_equipped BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, cosmetic_id)
);

CREATE INDEX IF NOT EXISTS idx_user_cosmetics_user_equipped
  ON public.user_cosmetics(user_id, is_equipped);
CREATE INDEX IF NOT EXISTS idx_user_cosmetics_cosmetic
  ON public.user_cosmetics(cosmetic_id);

DROP TRIGGER IF EXISTS tr_user_cosmetics_updated_at ON public.user_cosmetics;
CREATE TRIGGER tr_user_cosmetics_updated_at
  BEFORE UPDATE ON public.user_cosmetics
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.cosmetic_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_cosmetics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read active cosmetic catalog" ON public.cosmetic_catalog;
CREATE POLICY "Users can read active cosmetic catalog"
  ON public.cosmetic_catalog FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "Authenticated users can insert cosmetic catalog entries" ON public.cosmetic_catalog;
CREATE POLICY "Authenticated users can insert cosmetic catalog entries"
  ON public.cosmetic_catalog FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can update cosmetic catalog entries" ON public.cosmetic_catalog;
CREATE POLICY "Authenticated users can update cosmetic catalog entries"
  ON public.cosmetic_catalog FOR UPDATE
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users can delete cosmetic catalog entries" ON public.cosmetic_catalog;
CREATE POLICY "Authenticated users can delete cosmetic catalog entries"
  ON public.cosmetic_catalog FOR DELETE
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can read own cosmetics" ON public.user_cosmetics;
CREATE POLICY "Users can read own cosmetics"
  ON public.user_cosmetics FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own cosmetics" ON public.user_cosmetics;
CREATE POLICY "Users can insert own cosmetics"
  ON public.user_cosmetics FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own cosmetics" ON public.user_cosmetics;
CREATE POLICY "Users can update own cosmetics"
  ON public.user_cosmetics FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own cosmetics" ON public.user_cosmetics;
CREATE POLICY "Users can delete own cosmetics"
  ON public.user_cosmetics FOR DELETE
  USING (user_id = auth.uid());

INSERT INTO public.cosmetic_catalog (slug, name, cosmetic_type, asset_url, rarity, required_plan, is_active)
VALUES
  ('starlight-frame', 'Starlight Frame', 'avatar_decoration', 'https://cdn.flicko.app/cosmetics/starlight-frame.png', 'rare', 'nitro_basic', true),
  ('nebula-trail', 'Nebula Trail', 'profile_effect', 'https://cdn.flicko.app/cosmetics/nebula-trail.webm', 'epic', 'nitro_full', true),
  ('retro-nameplate', 'Retro Nameplate', 'nameplate', 'https://cdn.flicko.app/cosmetics/retro-nameplate.png', 'common', 'nitro_basic', true)
ON CONFLICT (slug) DO NOTHING;
