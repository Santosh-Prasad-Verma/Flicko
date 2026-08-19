-- Migration 173: Bot Developer Applications & SHA-256 Token Gateway

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

CREATE TABLE IF NOT EXISTS public.bot_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES public.bot_applications(id) ON DELETE CASCADE,
    token_prefix TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    scopes TEXT[] DEFAULT ARRAY['bot'],
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.bot_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_tokens ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Bot application owner read/write" ON public.bot_applications
        FOR ALL USING (owner_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Bot tokens owner read/write" ON public.bot_tokens
        FOR ALL USING (
            application_id IN (
                SELECT ba.id FROM public.bot_applications ba
                WHERE ba.owner_id = auth.uid()
            )
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
