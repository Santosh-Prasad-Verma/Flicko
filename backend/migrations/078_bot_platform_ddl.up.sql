-- ============================================================================
-- 078: Bot Platform Foundations DDL (Local Dev fallback)
-- ============================================================================

-- 1. Add is_bot to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_bot BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Create profiles table (since some services query public.profiles)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(32) NOT NULL UNIQUE,
    discriminator VARCHAR(4),
    display_name VARCHAR(64),
    pronouns VARCHAR(32),
    email VARCHAR(255) NOT NULL UNIQUE,
    avatar TEXT,
    banner TEXT,
    bio TEXT,
    status VARCHAR(30) DEFAULT 'offline',
    custom_status TEXT,
    custom_status_emoji TEXT,
    custom_status_expires_at TIMESTAMPTZ,
    accent_color VARCHAR(20),
    badges JSONB DEFAULT '[]'::jsonb,
    flags INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    is_bot BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create applications table
CREATE TABLE IF NOT EXISTS applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon_url TEXT,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    public_key TEXT,
    client_secret_hash TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Create bot_tokens table
CREATE TABLE IF NOT EXISTS bot_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    token_prefix TEXT NOT NULL,
    key_version VARCHAR(16) NOT NULL DEFAULT 'v1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bot_tokens_hash ON bot_tokens(token_hash) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bot_tokens_application ON bot_tokens(application_id);

-- 5. Create application_commands table
CREATE TABLE IF NOT EXISTS application_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000001',
    guild_id UUID REFERENCES servers(id) ON DELETE CASCADE,
    name VARCHAR(32) NOT NULL,
    description VARCHAR(100) NOT NULL DEFAULT '',
    options JSONB DEFAULT '[]'::jsonb,
    default_member_perms BIGINT,
    dm_permission BOOLEAN DEFAULT TRUE,
    type SMALLINT DEFAULT 1 CHECK (type IN (1, 2, 3)),
    nsfw BOOLEAN DEFAULT FALSE,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(application_id, guild_id, name)
);

-- 6. Create oauth2_grants table
CREATE TABLE IF NOT EXISTS oauth2_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    guild_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    scopes TEXT[] NOT NULL DEFAULT '{}',
    permissions BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(application_id, guild_id)
);

-- 7. Create permission_overwrites table
CREATE TABLE IF NOT EXISTS permission_overwrites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('role', 'member')),
    target_id UUID NOT NULL,
    allow BIGINT NOT NULL DEFAULT 0,
    deny BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(channel_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_permission_overwrites_channel_id ON permission_overwrites(channel_id);
CREATE INDEX IF NOT EXISTS idx_permission_overwrites_target_id ON permission_overwrites(target_id);

-- 8. Create audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID,
    reason TEXT,
    changes JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_server_id ON audit_logs(server_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target_id ON audit_logs(target_id);
