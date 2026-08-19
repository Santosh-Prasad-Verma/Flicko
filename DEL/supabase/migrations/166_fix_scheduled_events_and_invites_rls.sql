-- Migration 166: Fix RLS policies for scheduled_events, invites, and server_templates

-- 1. Scheduled Events RLS
CREATE TABLE IF NOT EXISTS public.scheduled_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    event_type TEXT NOT NULL DEFAULT 'text',
    location TEXT,
    image_url TEXT,
    interested_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.scheduled_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "scheduled_events_select_policy" ON public.scheduled_events;
DROP POLICY IF EXISTS "scheduled_events_insert_policy" ON public.scheduled_events;
DROP POLICY IF EXISTS "scheduled_events_update_policy" ON public.scheduled_events;
DROP POLICY IF EXISTS "scheduled_events_delete_policy" ON public.scheduled_events;
DROP POLICY IF EXISTS "Users can view scheduled events of servers they belong to" ON public.scheduled_events;
DROP POLICY IF EXISTS "Server members can create scheduled events" ON public.scheduled_events;
DROP POLICY IF EXISTS "Creators or admins can update scheduled events" ON public.scheduled_events;
DROP POLICY IF EXISTS "Creators or admins can delete scheduled events" ON public.scheduled_events;

CREATE POLICY "Users can view scheduled events of servers they belong to"
ON public.scheduled_events FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.server_members sm
        WHERE sm.server_id = scheduled_events.server_id
        AND sm.user_id = auth.uid()
    )
);

CREATE POLICY "Server members can create scheduled events"
ON public.scheduled_events FOR INSERT
WITH CHECK (
    auth.uid() = creator_id AND
    EXISTS (
        SELECT 1 FROM public.server_members sm
        WHERE sm.server_id = scheduled_events.server_id
        AND sm.user_id = auth.uid()
    )
);

CREATE POLICY "Creators or admins can update scheduled events"
ON public.scheduled_events FOR UPDATE
USING (
    auth.uid() = creator_id OR
    EXISTS (
        SELECT 1 FROM public.servers s
        WHERE s.id = scheduled_events.server_id AND s.owner_id = auth.uid()
    ) OR
    EXISTS (
        SELECT 1 FROM public.server_members sm
        JOIN public.roles r ON r.id = ANY(sm.roles)
        WHERE sm.server_id = scheduled_events.server_id
        AND sm.user_id = auth.uid()
        AND LOWER(r.name) IN ('admin', 'owner')
    )
);

CREATE POLICY "Creators or admins can delete scheduled events"
ON public.scheduled_events FOR DELETE
USING (
    auth.uid() = creator_id OR
    EXISTS (
        SELECT 1 FROM public.servers s
        WHERE s.id = scheduled_events.server_id AND s.owner_id = auth.uid()
    ) OR
    EXISTS (
        SELECT 1 FROM public.server_members sm
        JOIN public.roles r ON r.id = ANY(sm.roles)
        WHERE sm.server_id = scheduled_events.server_id
        AND sm.user_id = auth.uid()
        AND LOWER(r.name) IN ('admin', 'owner')
    )
);

-- 2. Invites Table RLS
CREATE TABLE IF NOT EXISTS public.invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    code TEXT UNIQUE NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    uses INT DEFAULT 0,
    max_uses INT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "invites_select_policy" ON public.invites;
DROP POLICY IF EXISTS "invites_insert_policy" ON public.invites;
DROP POLICY IF EXISTS "invites_delete_policy" ON public.invites;
DROP POLICY IF EXISTS "Anyone or server members can view invites" ON public.invites;
DROP POLICY IF EXISTS "Server members can create invites" ON public.invites;
DROP POLICY IF EXISTS "Invite creators or server admins can delete invites" ON public.invites;

CREATE POLICY "Anyone or server members can view invites"
ON public.invites FOR SELECT
USING (true);

CREATE POLICY "Server members can create invites"
ON public.invites FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.server_members sm
        WHERE sm.server_id = invites.server_id
        AND sm.user_id = auth.uid()
    )
);

CREATE POLICY "Invite creators or server admins can delete invites"
ON public.invites FOR DELETE
USING (
    created_by = auth.uid() OR
    EXISTS (
        SELECT 1 FROM public.servers s
        WHERE s.id = invites.server_id AND s.owner_id = auth.uid()
    ) OR
    EXISTS (
        SELECT 1 FROM public.server_members sm
        JOIN public.roles r ON r.id = ANY(sm.roles)
        WHERE sm.server_id = invites.server_id
        AND sm.user_id = auth.uid()
        AND LOWER(r.name) IN ('admin', 'owner')
    )
);

-- 3. Server Templates Table RLS
CREATE TABLE IF NOT EXISTS public.server_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    source_server_id UUID REFERENCES public.servers(id) ON DELETE SET NULL,
    creator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    serialized_data JSONB DEFAULT '{}'::jsonb,
    usage_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.server_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view server templates" ON public.server_templates;
DROP POLICY IF EXISTS "Authenticated users can create server templates" ON public.server_templates;
DROP POLICY IF EXISTS "Creators can delete server templates" ON public.server_templates;

CREATE POLICY "Anyone can view server templates"
ON public.server_templates FOR SELECT
USING (true);

CREATE POLICY "Authenticated users can create server templates"
ON public.server_templates FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Creators can delete server templates"
ON public.server_templates FOR DELETE
USING (creator_id = auth.uid());
