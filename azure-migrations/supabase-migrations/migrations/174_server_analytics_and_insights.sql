-- Migration 174: Server Analytics & Insights

CREATE TABLE IF NOT EXISTS public.server_analytics_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_members INT NOT NULL DEFAULT 0,
    active_members INT NOT NULL DEFAULT 0,
    new_joins INT NOT NULL DEFAULT 0,
    leaves INT NOT NULL DEFAULT 0,
    messages_count INT NOT NULL DEFAULT 0,
    voice_minutes INT NOT NULL DEFAULT 0,
    UNIQUE(server_id, snapshot_date)
);

ALTER TABLE public.server_analytics_daily ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Server admins view analytics" ON public.server_analytics_daily
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.server_members sm
            WHERE sm.server_id = server_analytics_daily.server_id
            AND sm.user_id = auth.uid()
        )
    );

-- SQL RPC to fetch formatted analytics timeline
CREATE OR REPLACE FUNCTION public.get_server_analytics_timeline(p_server_id UUID, p_days INT DEFAULT 30)
RETURNS TABLE (
    snapshot_date DATE,
    total_members INT,
    active_members INT,
    new_joins INT,
    messages_count INT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sad.snapshot_date,
        sad.total_members,
        sad.active_members,
        sad.new_joins,
        sad.messages_count
    FROM public.server_analytics_daily sad
    WHERE sad.server_id = p_server_id
    AND sad.snapshot_date >= CURRENT_DATE - p_days
    ORDER BY sad.snapshot_date ASC;
END;
$$;
