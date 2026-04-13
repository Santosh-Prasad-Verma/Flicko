-- 002_bot_system_tables.sql
-- Bot system tables for Docker-based local development.
-- Adapted from supabase/migrations/062_bot_system_tables.sql
-- (auth.users → users, no RLS, no auth.uid())

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─── Bot Registry ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS bots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    avatar_url TEXT,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    is_system BOOLEAN DEFAULT false,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bot_guilds (
    bot_id UUID NOT NULL REFERENCES bots(id) ON DELETE CASCADE,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    installed_by UUID REFERENCES users(id),
    permissions BIGINT DEFAULT 0,
    enabled BOOLEAN DEFAULT true,
    installed_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (bot_id, server_id)
);

-- ─── Moderation Bot Settings ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS mod_settings (
    server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT true,
    mod_log_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
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

CREATE TABLE IF NOT EXISTS temp_punishments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    moderator_id UUID REFERENCES users(id),
    type TEXT NOT NULL CHECK (type IN ('mute', 'ban')),
    reason TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_temp_punishments_expiry ON temp_punishments(expires_at) WHERE active = true;

-- ─── AutoMod Bot Settings ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS automod_settings (
    server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    log_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
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

-- ─── Welcome Bot Settings ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS welcome_settings (
    server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    welcome_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
    welcome_message TEXT DEFAULT 'Welcome to {{server}}, {{user}}! 🎉',
    welcome_embed BOOLEAN DEFAULT false,
    welcome_embed_color TEXT DEFAULT '#5865F2',
    welcome_embed_title TEXT DEFAULT 'Welcome!',
    welcome_card_enabled BOOLEAN DEFAULT false,
    welcome_card_bg_url TEXT,
    welcome_card_bg_color TEXT DEFAULT '#1a1a2e',
    welcome_card_text_color TEXT DEFAULT '#ffffff',
    dm_enabled BOOLEAN DEFAULT false,
    dm_message TEXT DEFAULT 'Welcome to **{{server}}**! Read the rules to get started.',
    leave_enabled BOOLEAN DEFAULT false,
    leave_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
    leave_message TEXT DEFAULT '**{{username}}** has left the server. 😢',
    auto_roles UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Leveling / XP System ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS level_settings (
    server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    xp_min INTEGER DEFAULT 15,
    xp_max INTEGER DEFAULT 25,
    cooldown_seconds INTEGER DEFAULT 60,
    level_up_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
    level_up_message TEXT DEFAULT '🎉 Congratulations {{user}}! You reached **Level {{level}}**!',
    no_xp_channels UUID[] DEFAULT '{}',
    stack_roles BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_xp (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 0,
    message_count INTEGER DEFAULT 0,
    last_xp_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, server_id)
);
CREATE INDEX IF NOT EXISTS idx_user_xp_leaderboard ON user_xp(server_id, xp DESC);

CREATE TABLE IF NOT EXISTS level_role_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    level INTEGER NOT NULL,
    role_id UUID NOT NULL,
    remove_previous BOOLEAN DEFAULT false,
    UNIQUE(server_id, level)
);

CREATE TABLE IF NOT EXISTS xp_multipliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('channel', 'role')),
    target_id UUID NOT NULL,
    multiplier NUMERIC(3,1) DEFAULT 1.0 CHECK (multiplier >= 0.0 AND multiplier <= 10.0),
    UNIQUE(server_id, target_type, target_id)
);

-- ─── Ticket System ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ticket_settings (
    server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    ticket_category_id UUID REFERENCES channels(id) ON DELETE SET NULL,
    staff_role_ids UUID[] DEFAULT '{}',
    ticket_prefix TEXT DEFAULT 'ticket',
    max_open_tickets INTEGER DEFAULT 3,
    log_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
    welcome_message TEXT DEFAULT 'A staff member will be with you shortly. Please describe your issue.',
    close_message TEXT DEFAULT 'This ticket has been closed. Thank you!',
    auto_close_hours INTEGER DEFAULT 48,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ticket_panels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    message_id UUID,
    title TEXT DEFAULT '🎫 Support Tickets',
    description TEXT DEFAULT 'Click the button below to create a support ticket.',
    button_label TEXT DEFAULT 'Create Ticket',
    button_color TEXT DEFAULT 'primary',
    category TEXT DEFAULT 'general',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ticket_number INTEGER NOT NULL,
    category TEXT DEFAULT 'general',
    subject TEXT,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed', 'archived')),
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    closed_by UUID REFERENCES users(id),
    closed_at TIMESTAMPTZ,
    added_users UUID[] DEFAULT '{}',
    first_response_at TIMESTAMPTZ,
    message_count INTEGER DEFAULT 0,
    last_activity_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tickets_server ON tickets(server_id, status);
CREATE INDEX IF NOT EXISTS idx_tickets_creator ON tickets(creator_id);

CREATE TABLE IF NOT EXISTS ticket_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(ticket_id, user_id)
);

-- ─── Starboard ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS starboard_settings (
    server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    starboard_channel_id UUID REFERENCES channels(id) ON DELETE SET NULL,
    star_threshold INTEGER DEFAULT 3,
    star_emoji TEXT DEFAULT '⭐',
    self_star BOOLEAN DEFAULT false,
    bot_messages BOOLEAN DEFAULT false,
    nsfw_allowed BOOLEAN DEFAULT false,
    ignored_channels UUID[] DEFAULT '{}',
    embed_color TEXT DEFAULT '#FFD700',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS starboard_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    original_message_id UUID NOT NULL,
    original_channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    starboard_message_id UUID,
    author_id UUID NOT NULL REFERENCES users(id),
    star_count INTEGER DEFAULT 0,
    content TEXT,
    attachments JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(server_id, original_message_id)
);
CREATE INDEX IF NOT EXISTS idx_starboard_entries_stars ON starboard_entries(server_id, star_count DESC);

CREATE TABLE IF NOT EXISTS starboard_stars (
    entry_id UUID NOT NULL REFERENCES starboard_entries(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (entry_id, user_id)
);

-- ─── Trigger: update updated_at ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  CREATE TRIGGER tr_mod_settings_updated_at BEFORE UPDATE ON mod_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_automod_settings_updated_at BEFORE UPDATE ON automod_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_welcome_settings_updated_at BEFORE UPDATE ON welcome_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_level_settings_updated_at BEFORE UPDATE ON level_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_ticket_settings_updated_at BEFORE UPDATE ON ticket_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_starboard_settings_updated_at BEFORE UPDATE ON starboard_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
