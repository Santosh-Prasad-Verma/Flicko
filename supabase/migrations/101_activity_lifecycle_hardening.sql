-- ============================================
-- Migration 101: Activity lifecycle hardening
-- ============================================
-- Goals:
-- 1) Resolve historical schema drift on public.activities so both
--    user presence activity and embedded activity catalog fields can coexist.
-- 2) Add activity_state_snapshots for synchronized activity state updates.

-- ── activities table normalization (supports both legacy and catalog fields) ──
DO $$
BEGIN
  -- Legacy presence-style columns (from migration 024) may be absent
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'type'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN type TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'details'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN details TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'state'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN state TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'metadata'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN metadata JSONB;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'started_at'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN started_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'ends_at'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN ends_at TIMESTAMPTZ;
  END IF;

  -- Catalog-style columns (from migration 053) may be absent
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'description'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN description TEXT DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'icon_url'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN icon_url TEXT DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'category'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN category TEXT DEFAULT 'games';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'max_participants'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN max_participants INTEGER DEFAULT 25;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'is_premium'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN is_premium BOOLEAN DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'embed_url'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN embed_url TEXT DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'developer'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN developer TEXT DEFAULT 'Flicko';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'avg_duration'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN avg_duration TEXT DEFAULT '~15 min';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'activities' AND column_name = 'enabled'
  ) THEN
    ALTER TABLE public.activities ADD COLUMN enabled BOOLEAN DEFAULT true;
  END IF;
END
$$;

-- Relax strict legacy constraints so catalog rows can exist without user_id/type.
ALTER TABLE public.activities ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.activities ALTER COLUMN type DROP NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'activities_type_check'
      AND conrelid = 'public.activities'::regclass
  ) THEN
    ALTER TABLE public.activities DROP CONSTRAINT activities_type_check;
  END IF;
END
$$;

-- Recreate flexible check:
-- - user activity rows: user_id + type present and type is a valid presence value
-- - catalog rows: user_id/type both null and category present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'activities_presence_or_catalog_check'
      AND conrelid = 'public.activities'::regclass
  ) THEN
    ALTER TABLE public.activities
      ADD CONSTRAINT activities_presence_or_catalog_check
      CHECK (
        (
          user_id IS NOT NULL
          AND type IN ('playing', 'streaming', 'listening', 'watching', 'custom')
        )
        OR
        (
          user_id IS NULL
          AND type IS NULL
          AND category IN ('games', 'watch_together', 'premium')
        )
      );
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_activities_enabled ON public.activities(enabled) WHERE enabled = true;

-- ── Activity synchronized state snapshots ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.activity_state_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.activity_sessions(id) ON DELETE CASCADE,
  version BIGINT NOT NULL,
  host_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  state_patch JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, version)
);

CREATE INDEX IF NOT EXISTS idx_activity_state_snapshots_session
  ON public.activity_state_snapshots(session_id, version DESC);

ALTER TABLE public.activity_state_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Server members can view activity snapshots"
  ON public.activity_state_snapshots FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.activity_sessions s
      JOIN public.server_members sm ON sm.server_id = s.server_id
      WHERE s.id = activity_state_snapshots.session_id
        AND sm.user_id = auth.uid()
    )
  );

CREATE POLICY "Session participants can insert activity snapshots"
  ON public.activity_state_snapshots FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.activity_participants p
      WHERE p.session_id = activity_state_snapshots.session_id
        AND p.user_id = auth.uid()
    )
  );

ALTER PUBLICATION supabase_realtime ADD TABLE public.activity_state_snapshots;
