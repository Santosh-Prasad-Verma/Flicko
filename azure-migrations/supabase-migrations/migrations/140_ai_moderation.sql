-- 140_ai_moderation.sql
-- AI Moderation: pre-send Llama-Guard scoring, mod queue, appeals.
-- See missing-features/03-ai/ai-moderation/SCHEMA.md
BEGIN;

CREATE TABLE IF NOT EXISTS public.mod_signals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id    UUID,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  server_id     UUID REFERENCES public.servers(id) ON DELETE SET NULL,
  channel_id    UUID REFERENCES public.channels(id) ON DELETE SET NULL,
  text_hash     TEXT NOT NULL,
  scores        JSONB NOT NULL,
  decision      TEXT NOT NULL CHECK (decision IN ('clean','review','blocked')),
  classifier    TEXT NOT NULL,
  classifier_v  TEXT NOT NULL,
  latency_ms    INT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ms_user_recent ON public.mod_signals(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ms_server      ON public.mod_signals(server_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ms_decision    ON public.mod_signals(decision, created_at DESC);

CREATE TABLE IF NOT EXISTS public.mod_thresholds (
  server_id   UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  category    TEXT NOT NULL,
  block_th    NUMERIC(4,3) NOT NULL,
  review_th   NUMERIC(4,3) NOT NULL,
  PRIMARY KEY (server_id, category)
);

CREATE TABLE IF NOT EXISTS public.mod_queue_items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id   UUID NOT NULL REFERENCES public.mod_signals(id) ON DELETE CASCADE,
  server_id   UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  text_plain  TEXT,                         -- purged on resolution; NULL = redacted
  status      TEXT NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','approved','denied')),
  decided_by  UUID REFERENCES auth.users(id),
  decided_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mqi_server_open
  ON public.mod_queue_items(server_id, created_at DESC)
  WHERE status = 'open';

CREATE TABLE IF NOT EXISTS public.mod_appeals (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id   UUID NOT NULL REFERENCES public.mod_signals(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason      TEXT,
  status      TEXT NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','overturned','upheld')),
  decided_by  UUID REFERENCES auth.users(id),
  decided_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ma_user_recent ON public.mod_appeals(user_id, created_at DESC);

ALTER TABLE public.mod_signals      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mod_thresholds   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mod_queue_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mod_appeals      ENABLE ROW LEVEL SECURITY;

-- Server owners + admins (any member with a manage permission, scoped via
-- server_members) read mod data. We deliberately keep this loose here and
-- enforce stricter perms in the handler — RLS is a backstop.
DROP POLICY IF EXISTS ms_member_read ON public.mod_signals;
CREATE POLICY ms_member_read ON public.mod_signals
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM public.server_members WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS mt_member_read ON public.mod_thresholds;
CREATE POLICY mt_member_read ON public.mod_thresholds
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM public.server_members WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS mqi_member_read ON public.mod_queue_items;
CREATE POLICY mqi_member_read ON public.mod_queue_items
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM public.server_members WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS ma_self ON public.mod_appeals;
CREATE POLICY ma_self ON public.mod_appeals
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.mod_signals, public.mod_thresholds, public.mod_queue_items, public.mod_appeals
  TO authenticated;

COMMIT;
