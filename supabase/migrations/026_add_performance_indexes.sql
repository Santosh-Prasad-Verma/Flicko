-- HIGH-011: Add missing performance indexes for production readiness

-- Composite index for Discord-style username#discriminator lookups
CREATE INDEX IF NOT EXISTS idx_profiles_username_discriminator ON profiles(username, discriminator);

-- Partial index for online status queries (excludes offline users for faster lookups)
CREATE INDEX IF NOT EXISTS idx_profiles_status_active ON profiles(status) WHERE status != 'offline';

-- Index for presence/last_seen queries (descending for "recently active" queries)
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON profiles(last_seen DESC);

-- Index for message queries by channel (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_messages_channel_created ON messages(channel_id, created_at DESC);

-- Index for message author lookups (edit/delete verification)
CREATE INDEX IF NOT EXISTS idx_messages_author ON messages(author_id);

-- Index for reactions by message (for loading reactions on messages)
CREATE INDEX IF NOT EXISTS idx_reactions_message ON reactions(message_id);

-- Index for server member lookups (access control checks)
CREATE INDEX IF NOT EXISTS idx_server_members_server_user ON server_members(server_id, user_id);

-- Index for voice states channel
CREATE INDEX IF NOT EXISTS idx_voice_states_channel ON voice_states(channel_id);

-- Index for voice states user
CREATE INDEX IF NOT EXISTS idx_voice_states_user ON voice_states(user_id);
