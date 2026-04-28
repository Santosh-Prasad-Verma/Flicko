-- Server Settings Tables Migration
-- Run this in Supabase SQL Editor to create all necessary tables

-- Music Settings Table (for Music Bot)
CREATE TABLE IF NOT EXISTS music_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(server_id)
);

-- Emojis Table
CREATE TABLE IF NOT EXISTS emojis (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    appwrite_file_id TEXT,
    appwrite_bucket_id TEXT,
    creator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(server_id, name)
);

-- Events Table
CREATE TABLE IF NOT EXISTS events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    image_url TEXT,
    channel_id UUID,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    attendee_count INTEGER DEFAULT 0,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invites Table (if not exists)
CREATE TABLE IF NOT EXISTS invites (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    code VARCHAR(20) UNIQUE NOT NULL,
    max_uses INTEGER,
    uses INTEGER DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Logs Table (if not exists)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action_type VARCHAR(50) NOT NULL,
    action_details JSONB,
    target_id UUID,
    target_type VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto Mod Rules Table (if not exists)
CREATE TABLE IF NOT EXISTS auto_mod_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    rule_name VARCHAR(100) NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    enabled BOOLEAN DEFAULT true,
    settings JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(server_id, rule_name)
);

-- Webhooks Table (if not exists)
CREATE TABLE IF NOT EXISTS webhooks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    url TEXT NOT NULL,
    secret TEXT,
    events TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Server Templates Table (if not exists)
CREATE TABLE IF NOT EXISTS server_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_preset BOOLEAN DEFAULT false,
    template_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bot Settings Tables for different bots
CREATE TABLE IF NOT EXISTS bot_welcome_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    welcome_message TEXT,
    welcome_channel_id UUID,
    UNIQUE(server_id)
);

CREATE TABLE IF NOT EXISTS bot_ticket_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    ticket_category_id UUID,
    UNIQUE(server_id)
);

CREATE TABLE IF NOT EXISTS bot_starboard_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    starboard_channel_id UUID,
    minimum_stars INTEGER DEFAULT 3,
    UNIQUE(server_id)
);

CREATE TABLE IF NOT EXISTS bot_poll_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    UNIQUE(server_id)
);

CREATE TABLE IF NOT EXISTS bot_leveling_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    xp_multiplier DECIMAL DEFAULT 1.0,
    UNIQUE(server_id)
);

CREATE TABLE IF NOT EXISTS bot_moderation_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    auto_mute BOOLEAN DEFAULT false,
    auto_kick BOOLEAN DEFAULT false,
    UNIQUE(server_id)
);

CREATE TABLE IF NOT EXISTS bot_automod_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT false,
    filter_invites BOOLEAN DEFAULT true,
    filter_links BOOLEAN DEFAULT true,
    filter_caps BOOLEAN DEFAULT false,
    filter_spam BOOLEAN DEFAULT true,
    UNIQUE(server_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_music_settings_server_id ON music_settings(server_id);
CREATE INDEX IF NOT EXISTS idx_emojis_server_id ON emojis(server_id);
CREATE INDEX IF NOT EXISTS idx_events_server_id ON events(server_id);
CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time);
CREATE INDEX IF NOT EXISTS idx_invites_server_id ON invites(server_id);
CREATE INDEX IF NOT EXISTS idx_invites_code ON invites(code);
CREATE INDEX IF NOT EXISTS idx_audit_logs_server_id ON audit_logs(server_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_auto_mod_rules_server_id ON auto_mod_rules(server_id);
CREATE INDEX IF NOT EXISTS idx_webhooks_server_id ON webhooks(server_id);
CREATE INDEX IF NOT EXISTS idx_server_templates_server_id ON server_templates(server_id);

-- Enable Row Level Security (RLS)
ALTER TABLE music_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE emojis ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE auto_mod_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_templates ENABLE ROW LEVEL SECURITY;

-- RLS Policies for music_settings
CREATE POLICY "Users can view music settings for their servers"
    ON music_settings FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can update music settings for their servers"
    ON music_settings FOR UPDATE
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

CREATE POLICY "Users can insert music settings for their servers"
    ON music_settings FOR INSERT
    WITH CHECK (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

-- RLS Policies for emojis
CREATE POLICY "Users can view emojis for their servers"
    ON emojis FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert emojis for their servers"
    ON emojis FOR INSERT
    WITH CHECK (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'moderator')));

CREATE POLICY "Users can delete emojis for their servers"
    ON emojis FOR DELETE
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'moderator')));

-- RLS Policies for events
CREATE POLICY "Users can view events for their servers"
    ON events FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert events for their servers"
    ON events FOR INSERT
    WITH CHECK (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'moderator')));

CREATE POLICY "Users can update events for their servers"
    ON events FOR UPDATE
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'moderator')));

CREATE POLICY "Users can delete events for their servers"
    ON events FOR DELETE
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'moderator')));

-- RLS Policies for invites
CREATE POLICY "Users can view invites for their servers"
    ON invites FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can manage invites for their servers"
    ON invites FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'moderator')));

-- RLS Policies for audit logs
CREATE POLICY "Users can view audit logs for their servers"
    ON audit_logs FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'moderator')));

-- RLS Policies for auto_mod_rules
CREATE POLICY "Users can view auto mod rules for their servers"
    ON auto_mod_rules FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can manage auto mod rules for their servers"
    ON auto_mod_rules FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

-- RLS Policies for webhooks
CREATE POLICY "Users can view webhooks for their servers"
    ON webhooks FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can manage webhooks for their servers"
    ON webhooks FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

-- RLS Policies for server_templates
CREATE POLICY "Users can view server templates"
    ON server_templates FOR SELECT
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can manage server templates"
    ON server_templates FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin'));

-- RLS Policies for bot settings tables
CREATE POLICY "Users can manage bot_welcome_settings"
    ON bot_welcome_settings FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

CREATE POLICY "Users can manage bot_ticket_settings"
    ON bot_ticket_settings FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

CREATE POLICY "Users can manage bot_starboard_settings"
    ON bot_starboard_settings FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

CREATE POLICY "Users can manage bot_poll_settings"
    ON bot_poll_settings FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

CREATE POLICY "Users can manage bot_leveling_settings"
    ON bot_leveling_settings FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

CREATE POLICY "Users can manage bot_moderation_settings"
    ON bot_moderation_settings FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

CREATE POLICY "Users can manage bot_automod_settings"
    ON bot_automod_settings FOR ALL
    USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND role IN ('owner', 'admin')));

-- Functions to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for auto-updating updated_at
CREATE TRIGGER update_music_settings_updated_at
    BEFORE UPDATE ON music_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_events_updated_at
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_auto_mod_rules_updated_at
    BEFORE UPDATE ON auto_mod_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_webhooks_updated_at
    BEFORE UPDATE ON webhooks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
