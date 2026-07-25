-- =============================================================================
-- 164: Complete the external-bot webhook path (continues 163)
-- =============================================================================
-- Applied to the remote project on 2026-07-25 (schema_migrations 20260725135808).
-- This file exists so the repo stays the authoritative source; the DDL below is
-- exactly what was applied.
--
-- webhook.go:133-143 issues this query on every dispatched event:
--
--   SELECT eb.id, eb.name, eb.webhook_url, eb.webhook_secret, eb.permissions
--   FROM external_bots eb
--   JOIN bot_event_subscriptions bes ON bes.bot_id = eb.id
--   JOIN bot_installations bi ON bi.bot_id = eb.id
--   WHERE bes.event_type = $1 AND bes.enabled = true
--     AND eb.status = 'approved' AND bi.server_id = $2 AND bi.enabled = true
--
-- 163 supplied bot_event_subscriptions, which moved the runtime error one join
-- further down. Still missing at that point:
--   * bot_installations            (table, from migration 095)
--   * external_bots.webhook_secret (column — live table has api_token/public_key)
--   * external_bots.status         (column — live table has is_active boolean)
--
-- This database is on the migration-127 "v2" shape of external_bots, which
-- diverged from the 095 shape the Go code was written against. Rather than
-- rewrite deployed code, add the columns it expects.
--
-- SECURITY NOTE: status defaults to 'pending', NOT 'approved'. The query above
-- only dispatches to approved bots, so pre-existing rows stay non-dispatching
-- until explicitly approved. Auto-approving them would silently begin sending
-- server events to unvetted webhook URLs.
--
-- All statements idempotent and purely additive.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.bot_installations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    installed_by UUID,
    enabled BOOLEAN NOT NULL DEFAULT true,
    installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (bot_id, server_id)
);

CREATE INDEX IF NOT EXISTS idx_bot_installations_server
    ON public.bot_installations(server_id) WHERE enabled = true;
CREATE INDEX IF NOT EXISTS idx_bot_installations_bot
    ON public.bot_installations(bot_id);

ALTER TABLE public.external_bots
    ADD COLUMN IF NOT EXISTS webhook_secret TEXT;

ALTER TABLE public.external_bots
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';

ALTER TABLE public.bot_installations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can view bot installations" ON public.bot_installations;
CREATE POLICY "Members can view bot installations" ON public.bot_installations FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.server_members
    WHERE server_members.server_id = bot_installations.server_id
      AND server_members.user_id = auth.uid()
  ));

DROP POLICY IF EXISTS "Server owners can manage bot installations" ON public.bot_installations;
CREATE POLICY "Server owners can manage bot installations" ON public.bot_installations FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.servers
    WHERE servers.id = bot_installations.server_id
      AND servers.owner_id = auth.uid()
  ));
