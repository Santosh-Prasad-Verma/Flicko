-- 003_advanced_features.sql

-- Server Boosts
CREATE TABLE IF NOT EXISTS public.server_boosts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_server_boosts_server_id ON public.server_boosts(server_id);
CREATE INDEX idx_server_boosts_user_id ON public.server_boosts(user_id);

CREATE TABLE IF NOT EXISTS public.server_boost_status (
  server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
  boost_count INTEGER NOT NULL DEFAULT 0,
  boost_level INTEGER NOT NULL DEFAULT 0 CHECK (boost_level >= 0 AND boost_level <= 3),
  perks JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Webhooks
CREATE TABLE IF NOT EXISTS public.webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES public.users(id),
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

-- Soundboard
CREATE TABLE IF NOT EXISTS soundboard_sounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 64),
  emoji TEXT DEFAULT '🔊',
  sound_url TEXT NOT NULL,
  duration REAL DEFAULT 0,
  uploaded_by UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  play_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS soundboard_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sound_id UUID NOT NULL REFERENCES soundboard_sounds(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, sound_id)
);

-- Activities
CREATE TABLE IF NOT EXISTS activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT DEFAULT '',
  icon_url TEXT DEFAULT '',
  category TEXT CHECK (category IN ('games', 'watch_together', 'premium')),
  max_participants INTEGER DEFAULT 25,
  is_premium BOOLEAN DEFAULT false,
  embed_url TEXT DEFAULT '',
  developer TEXT DEFAULT 'Flicko',
  avg_duration TEXT DEFAULT '~15 min',
  enabled BOOLEAN DEFAULT true,
  user_id UUID REFERENCES public.users(id),
  type TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS activity_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  host_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  state TEXT NOT NULL DEFAULT 'launching' CHECK (state IN ('idle', 'launching', 'active', 'closing', 'ended')),
  embed_url TEXT DEFAULT '',
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS activity_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES activity_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(session_id, user_id)
);

-- Bots
CREATE TABLE IF NOT EXISTS public.bots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    owner_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    avatar_url TEXT,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    is_system BOOLEAN DEFAULT false,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bot_guilds (
    bot_id UUID NOT NULL REFERENCES public.bots(id) ON DELETE CASCADE,
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    installed_by UUID REFERENCES public.users(id),
    permissions BIGINT DEFAULT 0,
    enabled BOOLEAN DEFAULT true,
    installed_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (bot_id, server_id)
);

-- Moderation
CREATE TABLE IF NOT EXISTS public.mod_settings (
    server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT true,
    mod_log_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    mute_role_id UUID,
    auto_role_id UUID,
    max_warnings INTEGER DEFAULT 3,
    max_warning_action TEXT DEFAULT 'mute' CHECK (max_warning_action IN ('mute', 'kick', 'ban')),
    anti_spam_enabled BOOLEAN DEFAULT true,
    anti_spam_threshold INTEGER DEFAULT 5,
    anti_spam_interval INTEGER DEFAULT 5,
    banned_words TEXT[] DEFAULT '{}',
    banned_words_action TEXT DEFAULT 'delete' CHECK (banned_words_action IN ('delete', 'warn', 'mute')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.automod_settings (
    server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    log_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    invite_filter BOOLEAN DEFAULT false,
    link_filter BOOLEAN DEFAULT false,
    caps_filter BOOLEAN DEFAULT false,
    caps_threshold INTEGER DEFAULT 70,
    emoji_filter BOOLEAN DEFAULT false,
    emoji_threshold INTEGER DEFAULT 10,
    mention_filter BOOLEAN DEFAULT false,
    mention_threshold INTEGER DEFAULT 5,
    duplicate_filter BOOLEAN DEFAULT false,
    duplicate_threshold INTEGER DEFAULT 3,
    exempt_roles UUID[] DEFAULT '{}',
    exempt_channels UUID[] DEFAULT '{}',
    exempt_users UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Welcome
CREATE TABLE IF NOT EXISTS public.welcome_settings (
    server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    welcome_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    welcome_message TEXT DEFAULT 'Welcome!',
    welcome_embed BOOLEAN DEFAULT false,
    welcome_embed_color TEXT DEFAULT '#5865F2',
    welcome_embed_title TEXT DEFAULT 'Welcome!',
    welcome_card_enabled BOOLEAN DEFAULT false,
    welcome_card_bg_url TEXT,
    welcome_card_bg_color TEXT DEFAULT '#1a1a2e',
    welcome_card_text_color TEXT DEFAULT '#ffffff',
    dm_enabled BOOLEAN DEFAULT false,
    dm_message TEXT DEFAULT 'Welcome!',
    leave_enabled BOOLEAN DEFAULT false,
    leave_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    leave_message TEXT DEFAULT 'Left',
    auto_roles UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Cosmetics
CREATE TABLE IF NOT EXISTS public.cosmetic_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  cosmetic_type TEXT NOT NULL,
  asset_url TEXT NOT NULL,
  rarity TEXT NOT NULL DEFAULT 'common',
  required_plan TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_cosmetics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  cosmetic_id UUID NOT NULL REFERENCES public.cosmetic_catalog(id) ON DELETE CASCADE,
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source TEXT NOT NULL DEFAULT 'subscription',
  is_equipped BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, cosmetic_id)
);

-- Stage Sessions
CREATE TABLE IF NOT EXISTS public.stage_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
  topic TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.stage_speaker_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.stage_sessions(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position > 0),
  status TEXT NOT NULL DEFAULT 'waiting',
  hand_raised_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  promoted_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- AI Summaries
CREATE TABLE IF NOT EXISTS public.ai_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL UNIQUE,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  requested_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  anchor_msg_id UUID,
  latest_msg_id UUID,
  window_start TIMESTAMPTZ NOT NULL,
  window_end TIMESTAMPTZ NOT NULL,
  message_count INT NOT NULL,
  bullets JSONB NOT NULL DEFAULT '[]'::jsonb,
  participants TEXT[] NOT NULL DEFAULT '{}',
  sentiment TEXT,
  model_used TEXT NOT NULL DEFAULT '',
  tokens_in INT,
  tokens_out INT,
  ttfb_ms INT,
  total_ms INT,
  outcome TEXT NOT NULL DEFAULT 'pending',
  refusal_reason TEXT,
  cache_key TEXT NOT NULL,
  cached_hit BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ
);

-- AI Moderation
CREATE TABLE IF NOT EXISTS public.mod_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  server_id UUID REFERENCES public.servers(id) ON DELETE SET NULL,
  channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
  text_hash TEXT NOT NULL,
  scores JSONB NOT NULL,
  decision TEXT NOT NULL CHECK (decision IN ('clean','review','blocked')),
  classifier TEXT NOT NULL,
  classifier_v TEXT NOT NULL,
  latency_ms INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Subscriptions
CREATE TABLE IF NOT EXISTS public.server_subscription_tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    tier_name TEXT NOT NULL,
    price_cents INT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    description TEXT,
    perks TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.member_server_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    tier_id UUID NOT NULL REFERENCES public.server_subscription_tiers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active',
    current_period_end TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(tier_id, user_id)
);
