-- Migration 172: Channel Permission Overrides & Role Icon Badges

-- Add icon_url to server_roles if not exists
ALTER TABLE public.server_roles
ADD COLUMN IF NOT EXISTS icon_url TEXT DEFAULT NULL;

-- Create channel_permission_overrides table
CREATE TABLE IF NOT EXISTS public.channel_permission_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.server_roles(id) ON DELETE CASCADE,
    allow_permissions BIGINT NOT NULL DEFAULT 0,
    deny_permissions BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(channel_id, role_id)
);

-- Enable RLS
ALTER TABLE public.channel_permission_overrides ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Channel permission overrides read access" ON public.channel_permission_overrides
    FOR SELECT USING (true);

CREATE POLICY "Channel permission overrides admin write access" ON public.channel_permission_overrides
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.channels c
            JOIN public.server_members sm ON sm.server_id = c.server_id
            WHERE c.id = channel_permission_overrides.channel_id
            AND sm.user_id = auth.uid()
            AND (sm.role = 'owner' OR sm.role = 'admin')
        )
    );
