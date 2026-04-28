-- Create external bots table for the new developer ecosystem
CREATE TABLE IF NOT EXISTS public.external_bots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    webhook_url TEXT NOT NULL,
    public_key TEXT,
    api_token TEXT UNIQUE,
    permissions TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index the lookups
CREATE INDEX IF NOT EXISTS idx_external_bots_server_id ON public.external_bots(server_id);
CREATE INDEX IF NOT EXISTS idx_external_bots_creator_id ON public.external_bots(creator_id);

-- Optional: External bot event subscriptions to avoid sending every event to every bot
CREATE TABLE IF NOT EXISTS public.external_bot_events (
    bot_id UUID REFERENCES public.external_bots(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    PRIMARY KEY (bot_id, event_type)
);

