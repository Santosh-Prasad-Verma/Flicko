-- ============================================
-- Migration 113: Extend bans with expiration/revocation
-- ============================================
-- Story P3-E2-S2-T3

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'bans'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'bans' AND column_name = 'expires_at'
    ) THEN
      ALTER TABLE public.bans ADD COLUMN expires_at TIMESTAMPTZ;
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'bans' AND column_name = 'revoked_at'
    ) THEN
      ALTER TABLE public.bans ADD COLUMN revoked_at TIMESTAMPTZ;
    END IF;

    CREATE INDEX IF NOT EXISTS idx_bans_expires_at ON public.bans(expires_at);
    CREATE INDEX IF NOT EXISTS idx_bans_revoked_at ON public.bans(revoked_at);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'server_bans'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'server_bans' AND column_name = 'expires_at'
    ) THEN
      ALTER TABLE public.server_bans ADD COLUMN expires_at TIMESTAMPTZ;
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'server_bans' AND column_name = 'revoked_at'
    ) THEN
      ALTER TABLE public.server_bans ADD COLUMN revoked_at TIMESTAMPTZ;
    END IF;

    CREATE INDEX IF NOT EXISTS idx_server_bans_expires_at ON public.server_bans(expires_at);
    CREATE INDEX IF NOT EXISTS idx_server_bans_revoked_at ON public.server_bans(revoked_at);
  END IF;
END $$;
