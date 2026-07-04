-- ============================================================================
-- 149: Bot Platform Foundations DDL
-- Adds: is_bot on profiles/users, client secret, public key, status on applications,
--        bot_tokens, oauth2_grants, and indexes.
-- ============================================================================

-- 1. Add is_bot to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_bot BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Alter applications to add public_key, client_secret_hash, status
ALTER TABLE public.applications ADD COLUMN IF NOT EXISTS public_key TEXT;
ALTER TABLE public.applications ADD COLUMN IF NOT EXISTS client_secret_hash TEXT;
ALTER TABLE public.applications ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'banned'));

-- 3. Create bot_tokens
CREATE TABLE IF NOT EXISTS public.bot_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    token_prefix TEXT NOT NULL,
    key_version VARCHAR(16) NOT NULL DEFAULT 'v1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

-- Index for fast token lookups (crucial for SHA-256 validation latency)
CREATE INDEX IF NOT EXISTS idx_bot_tokens_hash ON public.bot_tokens(token_hash) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bot_tokens_application ON public.bot_tokens(application_id);

-- Enable RLS for bot_tokens
ALTER TABLE public.bot_tokens ENABLE ROW LEVEL SECURITY;

-- Allow select/delete/insert to the application owner
DROP POLICY IF EXISTS "Owners can manage bot_tokens" ON public.bot_tokens;
CREATE POLICY "Owners can manage bot_tokens"
    ON public.bot_tokens FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.applications a
            WHERE a.id = bot_tokens.application_id AND a.owner_id = auth.uid()
        )
    );

-- 4. Ensure application_commands has the unique constraint/index
CREATE UNIQUE INDEX IF NOT EXISTS idx_application_commands_unique ON public.application_commands(application_id, guild_id, name);

-- 5. Create oauth2_grants table with unique constraint on application/guild
CREATE TABLE IF NOT EXISTS public.oauth2_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
    guild_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    scopes TEXT[] NOT NULL DEFAULT '{}',
    permissions BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(application_id, guild_id)
);

-- RLS for oauth2_grants
ALTER TABLE public.oauth2_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read grants for joined-server" ON public.oauth2_grants;
CREATE POLICY "Users can read grants for joined-server"
    ON public.oauth2_grants FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.server_members sm
            WHERE sm.server_id = oauth2_grants.guild_id AND sm.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Owners can manage grants" ON public.oauth2_grants;
CREATE POLICY "Owners can manage grants"
    ON public.oauth2_grants FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.applications a
            WHERE a.id = oauth2_grants.application_id AND a.owner_id = auth.uid()
        )
    );

-- 6. Ensure permission_overwrites unique index/constraint
CREATE UNIQUE INDEX IF NOT EXISTS idx_permission_overwrites_channel_target ON public.permission_overwrites(channel_id, target_id);
