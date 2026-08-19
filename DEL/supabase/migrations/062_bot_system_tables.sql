-- ============================================================================
-- 062: Complete Bot System Tables
-- Adds: bots, bot_guilds, slash_commands, mod_settings, welcome_settings,
--        level system, tickets, starboard, automod_settings
-- ============================================================================

-- ─── Bot Registry ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
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
    installed_by UUID REFERENCES auth.users(id),
    permissions BIGINT DEFAULT 0,
    enabled BOOLEAN DEFAULT true,
    installed_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (bot_id, server_id)
);

-- ─── Moderation Bot Settings ────────────────────────────────────────────────

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

CREATE TABLE IF NOT EXISTS public.temp_punishments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    moderator_id UUID REFERENCES auth.users(id),
    type TEXT NOT NULL CHECK (type IN ('mute', 'ban')),
    reason TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_temp_punishments_expiry ON public.temp_punishments(expires_at) WHERE active = true;

-- ─── AutoMod Bot Settings ───────────────────────────────────────────────────

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

-- ─── Welcome Bot Settings ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.welcome_settings (
    server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    welcome_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
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
    leave_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    leave_message TEXT DEFAULT '**{{username}}** has left the server. 😢',
    auto_roles UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Leveling / XP System ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.level_settings (
    server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    xp_min INTEGER DEFAULT 15,
    xp_max INTEGER DEFAULT 25,
    cooldown_seconds INTEGER DEFAULT 60,
    level_up_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    level_up_message TEXT DEFAULT '🎉 Congratulations {{user}}! You reached **Level {{level}}**!',
    no_xp_channels UUID[] DEFAULT '{}',
    stack_roles BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_xp (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 0,
    message_count INTEGER DEFAULT 0,
    last_xp_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, server_id)
);
CREATE INDEX IF NOT EXISTS idx_user_xp_leaderboard ON public.user_xp(server_id, xp DESC);

CREATE TABLE IF NOT EXISTS public.level_role_rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    level INTEGER NOT NULL,
    role_id UUID NOT NULL,
    remove_previous BOOLEAN DEFAULT false,
    UNIQUE(server_id, level)
);

CREATE TABLE IF NOT EXISTS public.xp_multipliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('channel', 'role')),
    target_id UUID NOT NULL,
    multiplier NUMERIC(3,1) DEFAULT 1.0 CHECK (multiplier >= 0.0 AND multiplier <= 10.0),
    UNIQUE(server_id, target_type, target_id)
);

-- ─── Ticket System ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.ticket_settings (
    server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    ticket_category_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    staff_role_ids UUID[] DEFAULT '{}',
    ticket_prefix TEXT DEFAULT 'ticket',
    max_open_tickets INTEGER DEFAULT 3,
    log_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    welcome_message TEXT DEFAULT 'A staff member will be with you shortly. Please describe your issue.',
    close_message TEXT DEFAULT 'This ticket has been closed. Thank you!',
    auto_close_hours INTEGER DEFAULT 48,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ticket_panels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    message_id UUID,
    title TEXT DEFAULT '🎫 Support Tickets',
    description TEXT DEFAULT 'Click the button below to create a support ticket.',
    button_label TEXT DEFAULT 'Create Ticket',
    button_color TEXT DEFAULT 'primary',
    category TEXT DEFAULT 'general',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ticket_number INTEGER NOT NULL,
    category TEXT DEFAULT 'general',
    subject TEXT,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed', 'archived')),
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    closed_by UUID REFERENCES auth.users(id),
    closed_at TIMESTAMPTZ,
    added_users UUID[] DEFAULT '{}',
    first_response_at TIMESTAMPTZ,
    message_count INTEGER DEFAULT 0,
    last_activity_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tickets_server ON public.tickets(server_id, status);
CREATE INDEX IF NOT EXISTS idx_tickets_creator ON public.tickets(creator_id);

CREATE TABLE IF NOT EXISTS public.ticket_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(ticket_id, user_id)
);

-- ─── Starboard ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.starboard_settings (
    server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    starboard_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
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

CREATE TABLE IF NOT EXISTS public.starboard_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    original_message_id UUID NOT NULL,
    original_channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    starboard_message_id UUID,
    author_id UUID NOT NULL REFERENCES auth.users(id),
    star_count INTEGER DEFAULT 0,
    content TEXT,
    attachments JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(server_id, original_message_id)
);
CREATE INDEX IF NOT EXISTS idx_starboard_entries_stars ON public.starboard_entries(server_id, star_count DESC);

CREATE TABLE IF NOT EXISTS public.starboard_stars (
    entry_id UUID NOT NULL REFERENCES public.starboard_entries(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (entry_id, user_id)
);

-- ─── RLS Policies ───────────────────────────────────────────────────────────

ALTER TABLE public.bots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_guilds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mod_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temp_punishments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.automod_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.welcome_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.level_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_xp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.level_role_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_multipliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_panels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.starboard_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.starboard_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.starboard_stars ENABLE ROW LEVEL SECURITY;

-- Server members can read bot settings for their servers
CREATE POLICY "Members can view mod_settings" ON public.mod_settings FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = mod_settings.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage mod_settings" ON public.mod_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = mod_settings.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Members can view automod_settings" ON public.automod_settings FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = automod_settings.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage automod_settings" ON public.automod_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = automod_settings.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Members can view welcome_settings" ON public.welcome_settings FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = welcome_settings.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage welcome_settings" ON public.welcome_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = welcome_settings.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Members can view level_settings" ON public.level_settings FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = level_settings.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage level_settings" ON public.level_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = level_settings.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Anyone can view user_xp in their servers" ON public.user_xp FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = user_xp.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "System can manage user_xp" ON public.user_xp FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Members can view level_role_rewards" ON public.level_role_rewards FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = level_role_rewards.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage level_role_rewards" ON public.level_role_rewards FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = level_role_rewards.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Members can view ticket_settings" ON public.ticket_settings FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = ticket_settings.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage ticket_settings" ON public.ticket_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = ticket_settings.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Members can view ticket_panels" ON public.ticket_panels FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = ticket_panels.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage ticket_panels" ON public.ticket_panels FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = ticket_panels.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Members can view their tickets" ON public.tickets FOR SELECT
  USING (creator_id = auth.uid() OR EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = tickets.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Members can create tickets" ON public.tickets FOR INSERT
  WITH CHECK (creator_id = auth.uid());

CREATE POLICY "Members can view starboard_settings" ON public.starboard_settings FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = starboard_settings.server_id AND server_members.user_id = auth.uid()));
CREATE POLICY "Server owner can manage starboard_settings" ON public.starboard_settings FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = starboard_settings.server_id AND servers.owner_id = auth.uid()));

CREATE POLICY "Members can view starboard_entries" ON public.starboard_entries FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = starboard_entries.server_id AND server_members.user_id = auth.uid()));

CREATE POLICY "Members can star messages" ON public.starboard_stars FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Anyone can view bots" ON public.bots FOR SELECT USING (true);
CREATE POLICY "Bot owners can manage bots" ON public.bots FOR ALL USING (owner_id = auth.uid());

CREATE POLICY "Members can view bot_guilds" ON public.bot_guilds FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = bot_guilds.server_id AND server_members.user_id = auth.uid()));

-- ─── Trigger: update updated_at ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  CREATE TRIGGER tr_mod_settings_updated_at BEFORE UPDATE ON public.mod_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_automod_settings_updated_at BEFORE UPDATE ON public.automod_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_welcome_settings_updated_at BEFORE UPDATE ON public.welcome_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_level_settings_updated_at BEFORE UPDATE ON public.level_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_ticket_settings_updated_at BEFORE UPDATE ON public.ticket_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER tr_starboard_settings_updated_at BEFORE UPDATE ON public.starboard_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ─── Edge Function for Bot Event Processing ─────────────────────────────────
-- The actual bot logic runs via Supabase Edge Functions and database triggers.
-- See supabase/functions/bot-engine/ for the implementation.
