-- Migration 177: Global App Directory & Bot OAuth2 Grants

CREATE TABLE IF NOT EXISTS public.app_directory_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.bot_applications(id) ON DELETE CASCADE,
    app_name TEXT NOT NULL,
    short_description TEXT NOT NULL,
    long_description TEXT,
    category TEXT NOT NULL DEFAULT 'Utility', -- Utility, Music, Moderation, Gaming
    icon_url TEXT,
    banner_url TEXT,
    install_count INT NOT NULL DEFAULT 0,
    is_featured BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.bot_oauth_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.bot_applications(id) ON DELETE CASCADE,
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    granted_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    granted_scopes TEXT[] NOT NULL DEFAULT ARRAY['bot'],
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(bot_id, server_id)
);

ALTER TABLE public.app_directory_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_oauth_grants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public view app directory listings" ON public.app_directory_listings
    FOR SELECT USING (true);

CREATE POLICY "Server admins manage bot oauth grants" ON public.bot_oauth_grants
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.servers s
            WHERE s.id = bot_oauth_grants.server_id
            AND s.owner_id = auth.uid()
        )
    );
