-- 138_ai_summaries.sql
-- Catch-Me-Up AI channel summary tables, RLS, and trigger.
-- See missing-features/03-ai/ai-message-summary/SCHEMA.md
BEGIN;

CREATE TABLE IF NOT EXISTS public.ai_summaries (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id        UUID NOT NULL UNIQUE,
  server_id         UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id        UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  requested_by      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anchor_msg_id     UUID,
  latest_msg_id     UUID,
  window_start      TIMESTAMPTZ NOT NULL,
  window_end        TIMESTAMPTZ NOT NULL,
  message_count     INT NOT NULL,
  bullets           JSONB NOT NULL DEFAULT '[]'::jsonb,
  participants      TEXT[] NOT NULL DEFAULT '{}',
  sentiment         TEXT,
  model_used        TEXT NOT NULL DEFAULT '',
  tokens_in         INT,
  tokens_out        INT,
  ttfb_ms           INT,
  total_ms          INT,
  outcome           TEXT NOT NULL DEFAULT 'pending'
                    CHECK (outcome IN ('pending','done','refused','error','rate_limited')),
  refusal_reason    TEXT,
  cache_key         TEXT NOT NULL,
  cached_hit        BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at       TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_summaries_channel
  ON public.ai_summaries (channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_summaries_user
  ON public.ai_summaries (requested_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_summaries_cache_key
  ON public.ai_summaries (cache_key);
CREATE INDEX IF NOT EXISTS idx_summaries_outcome
  ON public.ai_summaries (outcome);

CREATE TABLE IF NOT EXISTS public.ai_summary_feedback (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  summary_id   UUID NOT NULL REFERENCES public.ai_summaries(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating       SMALLINT NOT NULL CHECK (rating IN (-1, 1)),
  reason       TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (summary_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.ai_summary_anchors (
  user_id              UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_id           UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  last_summary_at      TIMESTAMPTZ,
  last_summary_anchor  UUID,
  PRIMARY KEY (user_id, channel_id)
);

ALTER TABLE public.ai_summaries        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_summary_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_summary_anchors  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS summaries_owner_read ON public.ai_summaries;
CREATE POLICY summaries_owner_read ON public.ai_summaries
  FOR SELECT USING (requested_by = auth.uid());

DROP POLICY IF EXISTS summaries_self_insert ON public.ai_summaries;
CREATE POLICY summaries_self_insert ON public.ai_summaries
  FOR INSERT WITH CHECK (requested_by = auth.uid());

DROP POLICY IF EXISTS summaries_self_update ON public.ai_summaries;
CREATE POLICY summaries_self_update ON public.ai_summaries
  FOR UPDATE USING (requested_by = auth.uid())
  WITH CHECK (requested_by = auth.uid());

DROP POLICY IF EXISTS summary_feedback_self ON public.ai_summary_feedback;
CREATE POLICY summary_feedback_self ON public.ai_summary_feedback
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS summary_anchors_self ON public.ai_summary_anchors;
CREATE POLICY summary_anchors_self ON public.ai_summary_anchors
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.update_summary_anchor() RETURNS trigger AS $$
BEGIN
  IF NEW.outcome = 'done' THEN
    INSERT INTO public.ai_summary_anchors (user_id, channel_id, last_summary_at, last_summary_anchor)
    VALUES (NEW.requested_by, NEW.channel_id, NEW.window_end, NEW.latest_msg_id)
    ON CONFLICT (user_id, channel_id)
    DO UPDATE SET last_summary_at     = EXCLUDED.last_summary_at,
                  last_summary_anchor = EXCLUDED.last_summary_anchor;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS summaries_update_anchor ON public.ai_summaries;
CREATE TRIGGER summaries_update_anchor
  AFTER UPDATE OF outcome ON public.ai_summaries
  FOR EACH ROW EXECUTE FUNCTION public.update_summary_anchor();

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.ai_summaries, public.ai_summary_feedback, public.ai_summary_anchors
  TO authenticated;

COMMIT;
