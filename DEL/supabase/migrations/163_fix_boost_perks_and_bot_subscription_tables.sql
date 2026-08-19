-- =============================================================================
-- 163: Repair schema drift — boost perks column + bot webhook support tables
-- =============================================================================
-- Applied to the remote project on 2026-07-25 (schema_migrations 20260725135558).
-- This file exists so the repo stays the authoritative source; the DDL below is
-- exactly what was applied.
--
-- 1. server_boost_status.perks (from migration 033) is absent in this database.
--    boost_service.go writes `perks` at two sites (UpdateBoostStatus paths), so
--    any boost add/remove failed with `column "perks" does not exist`.
--
-- 2. bot_event_subscriptions / bot_webhook_deliveries (from migration 095) were
--    never created. external_manager.go INSERTs into the former and webhook.go
--    JOINs it on every dispatched event, so every MESSAGE_CREATE /
--    MESSAGE_DELETE / MEMBER_* event logged
--    `relation "bot_event_subscriptions" does not exist (42P01)` and external
--    bot webhook delivery was entirely dead.
--
-- NOTE on RLS: migration 095 wrote these policies against
-- external_bots.developer_id, but THIS database is on the migration-127 ("v2")
-- shape of external_bots, which uses creator_id instead. Policies below are
-- written against the live column so they actually apply. Using the 095
-- wording here fails outright with `column external_bots.developer_id does not
-- exist`.
--
-- All statements idempotent and purely additive — no existing column or row is
-- altered or dropped. See 164 for the remainder of the webhook path.
-- =============================================================================

ALTER TABLE public.server_boost_status
    ADD COLUMN IF NOT EXISTS perks JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.bot_event_subscriptions (
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    PRIMARY KEY (bot_id, event_type)
);

CREATE INDEX IF NOT EXISTS idx_bot_event_subscriptions_type
    ON public.bot_event_subscriptions(event_type) WHERE enabled = true;

CREATE TABLE IF NOT EXISTS public.bot_webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_id UUID NOT NULL,
    server_id UUID,
    status_code INTEGER,
    response_time_ms INTEGER,
    success BOOLEAN DEFAULT false,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    delivered_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bot_webhook_deliveries_bot
    ON public.bot_webhook_deliveries(bot_id, delivered_at DESC);
CREATE INDEX IF NOT EXISTS idx_bot_webhook_deliveries_event
    ON public.bot_webhook_deliveries(event_id);
CREATE INDEX IF NOT EXISTS idx_bot_webhook_deliveries_time
    ON public.bot_webhook_deliveries(delivered_at DESC);

ALTER TABLE public.bot_event_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_webhook_deliveries  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Creators can manage bot subscriptions" ON public.bot_event_subscriptions;
CREATE POLICY "Creators can manage bot subscriptions" ON public.bot_event_subscriptions FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.external_bots
    WHERE external_bots.id = bot_event_subscriptions.bot_id
      AND external_bots.creator_id = auth.uid()
  ));

DROP POLICY IF EXISTS "Creators can view webhook deliveries" ON public.bot_webhook_deliveries;
CREATE POLICY "Creators can view webhook deliveries" ON public.bot_webhook_deliveries FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.external_bots
    WHERE external_bots.id = bot_webhook_deliveries.bot_id
      AND external_bots.creator_id = auth.uid()
  ));
