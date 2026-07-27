-- Migration 167: Fix external_bots (webhooks) and blocked_users RLS

-- 1. External Bots / Webhooks table
CREATE TABLE IF NOT EXISTS public.external_bots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    channel_id UUID REFERENCES public.channels(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(24), 'hex'),
    webhook_url TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.external_bots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Server members can view external bots" ON public.external_bots;
DROP POLICY IF EXISTS "Server admins or creators can insert external bots" ON public.external_bots;
DROP POLICY IF EXISTS "Server admins or creators can delete external bots" ON public.external_bots;

CREATE POLICY "Server members can view external bots"
ON public.external_bots FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.server_members sm
        WHERE sm.server_id = external_bots.server_id
        AND sm.user_id = auth.uid()
    )
);

CREATE POLICY "Server admins or creators can insert external bots"
ON public.external_bots FOR INSERT
WITH CHECK (
    auth.uid() IS NOT NULL AND
    EXISTS (
        SELECT 1 FROM public.server_members sm
        WHERE sm.server_id = external_bots.server_id
        AND sm.user_id = auth.uid()
    )
);

CREATE POLICY "Server admins or creators can delete external bots"
ON public.external_bots FOR DELETE
USING (
    creator_id = auth.uid() OR
    EXISTS (
        SELECT 1 FROM public.servers s
        WHERE s.id = external_bots.server_id AND s.owner_id = auth.uid()
    ) OR
    EXISTS (
        SELECT 1 FROM public.server_members sm
        JOIN public.roles r ON r.id = ANY(sm.roles)
        WHERE sm.server_id = external_bots.server_id
        AND sm.user_id = auth.uid()
        AND LOWER(r.name) IN ('admin', 'owner')
    )
);

-- 2. Blocked Users table
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, blocked_user_id)
);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their blocked list" ON public.blocked_users;
DROP POLICY IF EXISTS "Users can block others" ON public.blocked_users;
DROP POLICY IF EXISTS "Users can unblock others" ON public.blocked_users;

CREATE POLICY "Users can view their blocked list"
ON public.blocked_users FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can block others"
ON public.blocked_users FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unblock others"
ON public.blocked_users FOR DELETE
USING (auth.uid() = user_id);
