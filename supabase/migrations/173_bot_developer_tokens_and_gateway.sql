-- Migration 173: Bot Developer Applications & SHA-256 Token Gateway

-- Create bot_applications table
CREATE TABLE IF NOT EXISTS public.bot_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_name TEXT NOT NULL,
    bot_description TEXT,
    bot_avatar TEXT,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    public_bot BOOLEAN NOT NULL DEFAULT true,
    intents TEXT[] DEFAULT ARRAY['GUILD_MESSAGES', 'DIRECT_MESSAGES'],
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Create bot_tokens table with SHA-256 hashed secrets
CREATE TABLE IF NOT EXISTS public.bot_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.bot_applications(id) ON DELETE CASCADE,
    token_prefix TEXT NOT NULL, -- e.g. "bot_a8f9..."
    token_hash TEXT NOT NULL, -- SHA-256 hash of the raw token
    scopes TEXT[] DEFAULT ARRAY['bot'],
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE public.bot_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Bot application owner read/write" ON public.bot_applications
    FOR ALL USING (owner_id = auth.uid());

CREATE POLICY "Bot tokens owner read/write" ON public.bot_tokens
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.bot_applications ba
            WHERE ba.id = bot_tokens.bot_id
            AND ba.owner_id = auth.uid()
        )
    );
