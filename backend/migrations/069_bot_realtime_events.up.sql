-- ============================================================================
-- 069: Bot Realtime Events
-- Adds a table for broadcasting bot-driven events to clients via Realtime.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.bot_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    bot_name TEXT NOT NULL,
    event_type TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.bot_events;

-- RLS: Members can view events in their servers
ALTER TABLE public.bot_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view bot_events" ON public.bot_events FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = bot_events.server_id AND server_members.user_id = auth.uid()));
