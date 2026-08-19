-- 033_boost_integration_tables.sql

-- 1. Create server_boosts table
CREATE TABLE IF NOT EXISTS public.server_boosts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_server_boosts_server_id ON public.server_boosts(server_id);
CREATE INDEX idx_server_boosts_user_id ON public.server_boosts(user_id);
CREATE INDEX idx_server_boosts_expires_at ON public.server_boosts(expires_at) WHERE is_active = true;

-- 2. Create server_boost_status table
CREATE TABLE IF NOT EXISTS public.server_boost_status (
  server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
  boost_count INTEGER NOT NULL DEFAULT 0,
  boost_level INTEGER NOT NULL DEFAULT 0 CHECK (boost_level >= 0 AND boost_level <= 3),
  perks JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_server_boost_status_boost_level ON public.server_boost_status(boost_level);

-- 3. Create webhooks table
CREATE TABLE IF NOT EXISTS public.webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  avatar TEXT,
  webhook_type TEXT NOT NULL DEFAULT 'incoming' CHECK (webhook_type IN ('incoming', 'outgoing')),
  url TEXT UNIQUE NOT NULL,
  secret TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhooks_server_id ON public.webhooks(server_id);
CREATE INDEX idx_webhooks_channel_id ON public.webhooks(channel_id);
CREATE INDEX idx_webhooks_url ON public.webhooks(url);
