-- 024_user_management_tables.sql

-- 1. Create user_settings table
CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  theme TEXT NOT NULL DEFAULT 'dark' CHECK (theme IN ('light', 'dark', 'high-contrast')),
  notification_settings JSONB NOT NULL DEFAULT '{"desktop": true, "mobile": true, "email": false, "sounds": true}',
  privacy_settings JSONB NOT NULL DEFAULT '{"allow_dms_from_server_members": true, "show_activity_status": true}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Create sessions table
CREATE TABLE IF NOT EXISTS public.sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_info TEXT,
  ip_address TEXT,
  user_agent TEXT,
  refresh_token TEXT UNIQUE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_activity TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON public.sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON public.sessions(expires_at);

-- 3. Create connected_accounts table
CREATE TABLE IF NOT EXISTS public.connected_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('google', 'github', 'spotify', 'steam', 'xbox', 'twitch')),
  external_user_id TEXT NOT NULL,
  external_username TEXT,
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider, external_user_id),
  UNIQUE(user_id, provider)
);

CREATE INDEX idx_connected_accounts_user_id ON public.connected_accounts(user_id);

-- 4. Create presence table
CREATE TABLE IF NOT EXISTS public.presence (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online', 'idle', 'dnd', 'offline')),
  last_changed TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_presence_status ON public.presence(status);
CREATE INDEX idx_presence_last_changed ON public.presence(last_changed);

-- 5. Create activities table
CREATE TABLE IF NOT EXISTS public.activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('playing', 'streaming', 'listening', 'watching', 'custom')),
  name TEXT NOT NULL,
  details TEXT,
  state TEXT,
  metadata JSONB,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_activities_user_id ON public.activities(user_id);
CREATE INDEX idx_activities_type ON public.activities(type);
CREATE INDEX idx_activities_ends_at ON public.activities(ends_at);
