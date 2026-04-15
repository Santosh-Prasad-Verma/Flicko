-- ============================================
-- Phase 0: Parity baseline + schema governance
-- Migration 100
-- ============================================

-- Story P0-E1-S1: feature parity baseline table
CREATE TABLE IF NOT EXISTS feature_parity_status (
    feature_key     TEXT PRIMARY KEY,
    status          TEXT NOT NULL
                    CHECK (status IN ('missing', 'partial', 'implemented', 'planned', 'in_progress', 'done', 'blocked')),
    owner           TEXT NOT NULL DEFAULT 'unassigned',
    target_phase    TEXT NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feature_parity_status_phase
    ON feature_parity_status(target_phase);

CREATE INDEX IF NOT EXISTS idx_feature_parity_status_status
    ON feature_parity_status(status);

-- Seed a baseline set of feature buckets
INSERT INTO feature_parity_status (feature_key, status, owner, target_phase)
VALUES
    ('authentication_user_management', 'partial', 'platform', 'P2'),
    ('messaging', 'implemented', 'core-chat', 'P1'),
    ('servers_guilds', 'partial', 'communities', 'P3'),
    ('channels', 'implemented', 'core-chat', 'P1'),
    ('voice_video', 'partial', 'realtime-media', 'P4'),
    ('roles_permissions', 'partial', 'communities', 'P3'),
    ('moderation', 'partial', 'trust-safety', 'P3'),
    ('friends_social', 'partial', 'social', 'P3'),
    ('activities', 'partial', 'activities', 'P1'),
    ('notifications', 'partial', 'platform', 'P7'),
    ('premium_nitro', 'partial', 'monetization', 'P5'),
    ('bots_integrations', 'partial', 'ecosystem', 'P6'),
    ('discovery_intelligence', 'partial', 'growth', 'P8'),
    ('privacy_security', 'partial', 'trust-safety', 'P2'),
    ('platform_infrastructure', 'implemented', 'platform', 'P7')
ON CONFLICT (feature_key) DO NOTHING;

-- Story P0-E1-S2: schema version rollouts
CREATE TABLE IF NOT EXISTS schema_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain          TEXT NOT NULL,
    schema_type     TEXT NOT NULL CHECK (schema_type IN ('ws_event', 'rest_contract')),
    version         TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('draft', 'active', 'deprecated', 'retired')),
    checksum        TEXT,
    rolled_out_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(domain, schema_type, version)
);

CREATE INDEX IF NOT EXISTS idx_schema_versions_domain_type
    ON schema_versions(domain, schema_type);

CREATE INDEX IF NOT EXISTS idx_schema_versions_status
    ON schema_versions(status);

-- Reuse existing shared updated_at trigger function
DROP TRIGGER IF EXISTS tr_schema_versions_updated_at ON schema_versions;
CREATE TRIGGER tr_schema_versions_updated_at
    BEFORE UPDATE ON schema_versions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Seed initial WS event contract versions
INSERT INTO schema_versions (domain, schema_type, version, status, rolled_out_at)
VALUES
    ('MESSAGE', 'ws_event', 'v1', 'active', NOW()),
    ('VOICE', 'ws_event', 'v1', 'active', NOW()),
    ('ACTIVITY', 'ws_event', 'v1', 'active', NOW()),
    ('MOD', 'ws_event', 'v1', 'active', NOW())
ON CONFLICT (domain, schema_type, version) DO NOTHING;

CREATE TRIGGER handle_updated_at_feature_parity_status
    BEFORE UPDATE ON feature_parity_status
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();


ALTER TABLE feature_parity_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE schema_versions ENABLE ROW LEVEL SECURITY;
