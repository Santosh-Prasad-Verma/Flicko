-- ============================================================
-- Migration 072: End-to-End Encrypted Direct Messages (E2EE)
-- ============================================================
-- Design notes:
-- - The server NEVER sees plaintext or private keys.
-- - Identity keys: long-lived X25519 (32 bytes) for ECDH.
-- - Signed prekeys: medium-lived X25519, signed by Ed25519 identity sig key.
-- - One-time prekeys: pool of single-use X25519 keys for forward secrecy.
-- - DM messages carry: nonce (24 bytes), ciphertext, sender_ephemeral_pub.
-- - Recipients perform X25519(ephemeral_priv ⨉ recipient_pub) and decrypt with
--   XChaCha20-Poly1305.
-- - All public keys are stored as base64 to keep payloads JSON-friendly.

-- ── 1. Identity keys ─────────────────────────────────────────────────────────
-- One row per (user, device). A user may register multiple devices.
CREATE TABLE IF NOT EXISTS e2ee_identity_keys (
    user_id           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id         TEXT        NOT NULL,
    identity_pub      TEXT        NOT NULL,         -- base64 X25519 pub (32B)
    signing_pub       TEXT        NOT NULL,         -- base64 Ed25519 pub (32B)
    fingerprint       TEXT        NOT NULL,         -- SHA-256 of identity_pub (hex)
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rotated_at        TIMESTAMPTZ,
    PRIMARY KEY (user_id, device_id)
);
CREATE INDEX IF NOT EXISTS idx_e2ee_identity_user ON e2ee_identity_keys (user_id);

-- ── 2. Signed prekeys ────────────────────────────────────────────────────────
-- Rotated periodically; signed by identity signing key for authenticity.
CREATE TABLE IF NOT EXISTS e2ee_signed_prekeys (
    id                BIGSERIAL   PRIMARY KEY,
    user_id           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id         TEXT        NOT NULL,
    key_id            INT         NOT NULL,         -- monotonic per device
    public_key        TEXT        NOT NULL,         -- base64 X25519 pub
    signature         TEXT        NOT NULL,         -- base64 Ed25519 sig over public_key
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at        TIMESTAMPTZ,
    UNIQUE (user_id, device_id, key_id)
);
CREATE INDEX IF NOT EXISTS idx_e2ee_signed_prekey_user
    ON e2ee_signed_prekeys (user_id, device_id);

-- ── 3. One-time prekeys ──────────────────────────────────────────────────────
-- Each row is consumed (deleted) on first use. Recipient should keep the pool topped up.
CREATE TABLE IF NOT EXISTS e2ee_one_time_prekeys (
    id                BIGSERIAL   PRIMARY KEY,
    user_id           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id         TEXT        NOT NULL,
    key_id            INT         NOT NULL,
    public_key        TEXT        NOT NULL,         -- base64 X25519 pub
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, device_id, key_id)
);
CREATE INDEX IF NOT EXISTS idx_e2ee_otk_user_device
    ON e2ee_one_time_prekeys (user_id, device_id);

-- ── 4. Encrypted DM payload columns ──────────────────────────────────────────
-- Add columns to existing direct_messages table; plaintext `content` is left
-- empty for encrypted messages (can be a sentinel marker like '[encrypted]').
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'direct_messages') THEN
        ALTER TABLE direct_messages
            ADD COLUMN IF NOT EXISTS is_encrypted        BOOLEAN     NOT NULL DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS ciphertext          TEXT,                       -- base64
            ADD COLUMN IF NOT EXISTS nonce               TEXT,                       -- base64 (24B XChaCha20 nonce)
            ADD COLUMN IF NOT EXISTS sender_ephemeral_pub TEXT,                      -- base64 X25519 pub
            ADD COLUMN IF NOT EXISTS sender_device_id    TEXT,
            ADD COLUMN IF NOT EXISTS recipient_device_id TEXT,
            ADD COLUMN IF NOT EXISTS prekey_id           INT,                        -- which one-time prekey was used
            ADD COLUMN IF NOT EXISTS signed_prekey_id    INT;
    END IF;
END$$;

-- ── 5. Per-conversation E2EE flag ────────────────────────────────────────────
-- Once enabled, all subsequent messages MUST be encrypted; cannot be disabled
-- (matches Signal/Matrix policy).
CREATE TABLE IF NOT EXISTS e2ee_conversation_state (
    user_a            UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_b            UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    enabled           BOOLEAN     NOT NULL DEFAULT FALSE,
    enabled_at        TIMESTAMPTZ,
    PRIMARY KEY (user_a, user_b),
    CHECK (user_a < user_b)        -- canonical ordering so each pair has one row
);

-- ── 6. Helper view: get latest signed prekey per user/device ────────────────
CREATE OR REPLACE VIEW e2ee_latest_signed_prekey AS
SELECT DISTINCT ON (user_id, device_id)
    user_id, device_id, key_id, public_key, signature, created_at
FROM e2ee_signed_prekeys
WHERE expires_at IS NULL OR expires_at > NOW()
ORDER BY user_id, device_id, created_at DESC;

-- ── 7. RLS (defense in depth) ────────────────────────────────────────────────
ALTER TABLE e2ee_identity_keys      ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_signed_prekeys     ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_one_time_prekeys   ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_conversation_state ENABLE ROW LEVEL SECURITY;

-- Public-key tables are world-readable to authenticated users (that's the point of public keys).
DROP POLICY IF EXISTS e2ee_identity_keys_read    ON e2ee_identity_keys;
DROP POLICY IF EXISTS e2ee_signed_prekeys_read   ON e2ee_signed_prekeys;
DROP POLICY IF EXISTS e2ee_one_time_prekeys_read ON e2ee_one_time_prekeys;

CREATE POLICY e2ee_identity_keys_read    ON e2ee_identity_keys
    FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY e2ee_signed_prekeys_read   ON e2ee_signed_prekeys
    FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY e2ee_one_time_prekeys_read ON e2ee_one_time_prekeys
    FOR SELECT TO authenticated USING (TRUE);

-- Writes: only the owning user.
DROP POLICY IF EXISTS e2ee_identity_keys_write    ON e2ee_identity_keys;
DROP POLICY IF EXISTS e2ee_signed_prekeys_write   ON e2ee_signed_prekeys;
DROP POLICY IF EXISTS e2ee_one_time_prekeys_write ON e2ee_one_time_prekeys;

CREATE POLICY e2ee_identity_keys_write    ON e2ee_identity_keys
    FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY e2ee_signed_prekeys_write   ON e2ee_signed_prekeys
    FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY e2ee_one_time_prekeys_write ON e2ee_one_time_prekeys
    FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Conversation state: visible to both participants.
DROP POLICY IF EXISTS e2ee_conv_state_select ON e2ee_conversation_state;
DROP POLICY IF EXISTS e2ee_conv_state_write  ON e2ee_conversation_state;

CREATE POLICY e2ee_conv_state_select ON e2ee_conversation_state
    FOR SELECT TO authenticated
    USING (user_a = auth.uid() OR user_b = auth.uid());
CREATE POLICY e2ee_conv_state_write  ON e2ee_conversation_state
    FOR ALL TO authenticated
    USING (user_a = auth.uid() OR user_b = auth.uid())
    WITH CHECK (user_a = auth.uid() OR user_b = auth.uid());
