-- ============================================
-- PHASE 2: RICH EXPERIENCE - ALL REMAINING TABLES
-- Migration 054
-- ============================================

-- ============================================
-- 1. APPLICATION COMMANDS & INTERACTIONS
-- ============================================

CREATE TABLE IF NOT EXISTS application_commands (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id          UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
    guild_id                UUID REFERENCES servers(id) ON DELETE CASCADE,
    name                    VARCHAR(32) NOT NULL,
    description             VARCHAR(100) NOT NULL DEFAULT '',
    options                 JSONB DEFAULT '[]'::jsonb,
    default_member_perms    BIGINT,
    dm_permission           BOOLEAN DEFAULT TRUE,
    type                    SMALLINT DEFAULT 1 CHECK (type IN (1, 2, 3)),
    nsfw                    BOOLEAN DEFAULT FALSE,
    version                 BIGINT NOT NULL DEFAULT 1,
    created_at              TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(application_id, guild_id, name)
);

CREATE TABLE IF NOT EXISTS interactions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id          UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
    type                    SMALLINT NOT NULL CHECK (type IN (1, 2, 3, 4, 5)),
    guild_id                UUID REFERENCES servers(id) ON DELETE SET NULL,
    channel_id              UUID,
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token                   VARCHAR(255) NOT NULL UNIQUE DEFAULT gen_random_uuid()::text,
    data                    JSONB DEFAULT '{}'::jsonb,
    version                 INT DEFAULT 1,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    responded               BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_interactions_token ON interactions(token);
CREATE INDEX IF NOT EXISTS idx_interactions_user ON interactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_commands_guild ON application_commands(guild_id) WHERE guild_id IS NOT NULL;

-- Enable RLS
ALTER TABLE application_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

-- Commands: anyone in the server can read commands
CREATE POLICY "Anyone can read commands"
    ON application_commands FOR SELECT
    USING (
        guild_id IS NULL
        OR guild_id IN (
            SELECT server_id FROM server_members WHERE user_id = auth.uid()
        )
    );

-- Commands: only server admins can manage guild commands
CREATE POLICY "Admins can manage commands"
    ON application_commands FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.servers s
            WHERE s.id = guild_id AND s.owner_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.server_members sm
            WHERE sm.server_id = guild_id
              AND sm.user_id = auth.uid()
              AND (SELECT id FROM public.roles r WHERE r.server_id = guild_id AND r.name = 'Admin') = ANY(sm.roles)
        )
    );

-- Interactions: users can read their own
CREATE POLICY "Users can read own interactions"
    ON interactions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can create interactions"
    ON interactions FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "System can update interactions"
    ON interactions FOR UPDATE
    USING (true);

-- ============================================
-- 2. SUBSCRIPTIONS & ENTITLEMENTS
-- ============================================

CREATE TABLE IF NOT EXISTS subscriptions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan                    VARCHAR(32) NOT NULL CHECK (plan IN ('nitro_basic', 'nitro_full')),
    status                  VARCHAR(32) NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active', 'grace_period', 'expired', 'revoked', 'paused', 'cancelled')),
    store                   VARCHAR(16) NOT NULL DEFAULT 'dev_mock'
                            CHECK (store IN ('app_store', 'play_store', 'dev_mock')),
    revenuecat_id           VARCHAR(255) UNIQUE,
    current_period_start    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_end      TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    cancel_at_period_end    BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_active_user
    ON subscriptions(user_id) WHERE status IN ('active', 'grace_period');

CREATE TABLE IF NOT EXISTS entitlements (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type                    VARCHAR(64) NOT NULL,
    source                  VARCHAR(32) NOT NULL DEFAULT 'subscription'
                            CHECK (source IN ('subscription', 'purchase', 'gift', 'dev_grant')),
    source_id               UUID,
    granted_at              TIMESTAMPTZ DEFAULT NOW(),
    expires_at              TIMESTAMPTZ,
    revoked                 BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_entitlements_user
    ON entitlements(user_id, type) WHERE revoked = FALSE;

-- Enable RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE entitlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own subscriptions"
    ON subscriptions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage own subscriptions"
    ON subscriptions FOR ALL
    USING (user_id = auth.uid());

CREATE POLICY "Users can read own entitlements"
    ON entitlements FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage own entitlements"
    ON entitlements FOR ALL
    USING (user_id = auth.uid());

-- ============================================
-- 3. EMOJI ENHANCEMENTS (role restriction + usage stats)
-- ============================================

-- Add role restriction and usage stats to server_emojis (created in migration 052)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_name = 'server_emojis' AND column_name = 'allowed_roles') THEN
        ALTER TABLE server_emojis ADD COLUMN allowed_roles UUID[] DEFAULT '{}';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_name = 'server_emojis' AND column_name = 'usage_count') THEN
        ALTER TABLE server_emojis ADD COLUMN usage_count BIGINT DEFAULT 0;
    END IF;
END
$$;

-- Function to increment emoji usage count
CREATE OR REPLACE FUNCTION increment_emoji_usage(emoji_uuid UUID)
RETURNS void AS $$
BEGIN
    UPDATE server_emojis
    SET usage_count = usage_count + 1
    WHERE id = emoji_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 4. SEARCH ENHANCEMENTS
-- ============================================

-- Add ts_headline support function for search highlighting
CREATE OR REPLACE FUNCTION search_messages_with_highlights(
    search_query TEXT,
    channel_ids UUID[],
    result_limit INT DEFAULT 25,
    result_offset INT DEFAULT 0,
    sort_order TEXT DEFAULT 'relevance'
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    highlighted_content TEXT,
    author_id UUID,
    channel_id UUID,
    server_id UUID,
    created_at TIMESTAMPTZ,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.content,
        ts_headline(
            'english',
            m.content,
            websearch_to_tsquery('english', search_query),
            'StartSel=**,StopSel=**,MaxWords=50,MinWords=20,MaxFragments=2'
        ) AS highlighted_content,
        m.author_id,
        m.channel_id,
        c.server_id,
        m.created_at,
        ts_rank(to_tsvector('english', m.content), websearch_to_tsquery('english', search_query)) AS rank
    FROM messages m
    JOIN channels c ON c.id = m.channel_id
    WHERE m.channel_id = ANY(channel_ids)
      AND to_tsvector('english', m.content) @@ websearch_to_tsquery('english', search_query)
    ORDER BY
        CASE WHEN sort_order = 'relevance' THEN
            ts_rank(to_tsvector('english', m.content), websearch_to_tsquery('english', search_query))
        END DESC NULLS LAST,
        CASE WHEN sort_order = 'newest' THEN extract(epoch from m.created_at) END DESC NULLS LAST,
        CASE WHEN sort_order = 'oldest' THEN extract(epoch from m.created_at) END ASC NULLS LAST
    LIMIT result_limit
    OFFSET result_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. SEED DEFAULT SLASH COMMANDS
-- ============================================

INSERT INTO application_commands (name, description, options, type) VALUES
('poll', 'Create a poll for the channel', '[
    {"name": "question", "description": "The poll question", "type": 3, "required": true},
    {"name": "option1", "description": "First option", "type": 3, "required": true},
    {"name": "option2", "description": "Second option", "type": 3, "required": true},
    {"name": "option3", "description": "Third option (optional)", "type": 3, "required": false},
    {"name": "option4", "description": "Fourth option (optional)", "type": 3, "required": false}
]', 1),
('ban', 'Ban a member from the server', '[
    {"name": "user", "description": "The user to ban", "type": 6, "required": true},
    {"name": "reason", "description": "Reason for the ban", "type": 3, "required": false},
    {"name": "delete_days", "description": "Days of messages to delete (0-7)", "type": 4, "required": false, "min_value": 0, "max_value": 7}
]', 1),
('kick', 'Kick a member from the server', '[
    {"name": "user", "description": "The user to kick", "type": 6, "required": true},
    {"name": "reason", "description": "Reason for the kick", "type": 3, "required": false}
]', 1),
('mute', 'Mute a member in the server', '[
    {"name": "user", "description": "The user to mute", "type": 6, "required": true},
    {"name": "duration", "description": "Mute duration (e.g. 10m, 1h, 1d)", "type": 3, "required": true},
    {"name": "reason", "description": "Reason for the mute", "type": 3, "required": false}
]', 1),
('play', 'Play a song in voice channel', '[
    {"name": "query", "description": "Song name or URL", "type": 3, "required": true}
]', 1),
('search', 'Search messages in this server', '[
    {"name": "query", "description": "Search query", "type": 3, "required": true},
    {"name": "from", "description": "Filter by author", "type": 6, "required": false},
    {"name": "in", "description": "Filter by channel", "type": 7, "required": false}
]', 1),
('clear', 'Delete multiple messages', '[
    {"name": "amount", "description": "Number of messages to delete (1-100)", "type": 4, "required": true, "min_value": 1, "max_value": 100}
]', 1),
('serverinfo', 'Display server information', '[]', 1),
('userinfo', 'Display user information', '[
    {"name": "user", "description": "The user to look up", "type": 6, "required": false}
]', 1),
('remind', 'Set a reminder', '[
    {"name": "time", "description": "When to remind (e.g. 30m, 2h, 1d)", "type": 3, "required": true},
    {"name": "message", "description": "Reminder message", "type": 3, "required": true}
]', 1),
('8ball', 'Ask the magic 8-ball a question', '[
    {"name": "question", "description": "Your question", "type": 3, "required": true}
]', 1),
('coinflip', 'Flip a coin', '[]', 1),
('avatar', 'Get a user''s avatar', '[
    {"name": "user", "description": "The user (defaults to you)", "type": 6, "required": false}
]', 1)
ON CONFLICT DO NOTHING;

-- ============================================
-- 6. SEED DEFAULT NITRO ENTITLEMENTS FOR DEV
-- ============================================

-- Dev helper: grant Nitro to a user (call manually)
CREATE OR REPLACE FUNCTION dev_grant_nitro(target_user_id UUID, nitro_plan TEXT DEFAULT 'nitro_full')
RETURNS void AS $$
BEGIN
    INSERT INTO subscriptions (user_id, plan, status, store, current_period_start, current_period_end)
    VALUES (target_user_id, nitro_plan, 'active', 'dev_mock', NOW(), NOW() + INTERVAL '365 days')
    ON CONFLICT (user_id) WHERE status IN ('active', 'grace_period')
    DO UPDATE SET plan = nitro_plan, current_period_end = NOW() + INTERVAL '365 days', updated_at = NOW();

    INSERT INTO entitlements (user_id, type, source)
    VALUES (target_user_id, nitro_plan, 'dev_grant')
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable realtime for new tables
ALTER PUBLICATION supabase_realtime ADD TABLE application_commands;
ALTER PUBLICATION supabase_realtime ADD TABLE subscriptions;
ALTER PUBLICATION supabase_realtime ADD TABLE entitlements;
