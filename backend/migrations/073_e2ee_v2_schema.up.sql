-- ============================================================
-- Migration 073: E2EE v2 — sealed-sender, backup, audit, escrow
-- ============================================================
-- Phase 0 deliverable. Backwards compatible with v1 (072_e2ee_schema).
-- Server NEVER stores plaintext, private keys, or backup master keys.
-- All public-key tables: read-public, write-owner-only via RLS.

-- ── 1. Sealed-sender envelope relay ──────────────────────────────────────────
-- Each envelope is one (sender_device → recipient_device) ciphertext.
-- The server fans out N envelopes per send (one per recipient device).
CREATE TABLE IF NOT EXISTS e2ee_message_envelopes (
    id                  BIGSERIAL   PRIMARY KEY,
    sender_user_id      UUID,                                       -- NULL when sealed
    sender_device_id    TEXT,
    recipient_user_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_device_id TEXT        NOT NULL,
    is_sealed           BOOLEAN     NOT NULL DEFAULT FALSE,
    header              BYTEA       NOT NULL,                       -- DR header (DHr, PN, Ns)
    ciphertext          BYTEA       NOT NULL,                       -- AEAD output incl. tag
    delivery_token      BYTEA,                                      -- abuse token (sealed only)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_e2ee_envelope_inbox
    ON e2ee_message_envelopes (recipient_user_id, recipient_device_id, id);
CREATE INDEX IF NOT EXISTS idx_e2ee_envelope_gc
    ON e2ee_message_envelopes (created_at);

-- ── 2. Verification audit log (append-only) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS e2ee_verification_events (
    id           BIGSERIAL   PRIMARY KEY,
    user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    peer_user_id UUID        NOT NULL,
    method       TEXT        NOT NULL CHECK (method IN
                              ('safety_number','qr','sas','identity_change_ack')),
    fingerprint  TEXT        NOT NULL,                              -- hex(SHA-256(peer_IK_pub))
    occurred_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_e2ee_verification_user_time
    ON e2ee_verification_events (user_id, occurred_at DESC);

-- ── 3. Encrypted backup chunks ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS e2ee_backups (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    salt        BYTEA       NOT NULL,                                -- Argon2id salt
    chunk_index INT         NOT NULL,
    chunk_hash  BYTEA       NOT NULL,                                -- SHA-256 of ciphertext
    ciphertext  BYTEA       NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, chunk_hash)
);
CREATE INDEX IF NOT EXISTS idx_e2ee_backups_user_index
    ON e2ee_backups (user_id, chunk_index);

-- ── 4. Org-tenant escrow registry (off by default) ───────────────────────────
CREATE TABLE IF NOT EXISTS e2ee_escrow_keys (
    org_id     UUID        PRIMARY KEY,
    public_key BYTEA       NOT NULL,                                 -- X25519 pub
    custodians UUID[]      NOT NULL,                                 -- approver users
    threshold  INT         NOT NULL CHECK (threshold > 0),
    enabled    BOOLEAN     NOT NULL DEFAULT FALSE,                   -- MUST stay false for personal accounts (R11.1)
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 5. Multi-device handoff coordinator ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS e2ee_handoff_requests (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    new_device_id        TEXT        NOT NULL,
    new_device_identity  BYTEA       NOT NULL,                       -- X25519 pub of joiner
    sas_fingerprint      TEXT        NOT NULL,                       -- 6-word safety phrase
    status               TEXT        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','approved','rejected','expired')),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at           TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '10 minutes'
);
CREATE INDEX IF NOT EXISTS idx_e2ee_handoff_user_status
    ON e2ee_handoff_requests (user_id, status);

-- ── 6. Tag the legacy direct_messages table with a protocol version ──────────
-- v1 envelopes default to 'v1' so existing rows decrypt unchanged (R16.1).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'direct_messages') THEN
        ALTER TABLE direct_messages
            ADD COLUMN IF NOT EXISTS e2ee_protocol_version TEXT NOT NULL DEFAULT 'v1'
                CHECK (e2ee_protocol_version IN ('v1','v2','plain'));
    END IF;
END$$;

-- ── 7. Row-level security ────────────────────────────────────────────────────
ALTER TABLE e2ee_message_envelopes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_verification_events  ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_backups              ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_escrow_keys          ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_handoff_requests     ENABLE ROW LEVEL SECURITY;

-- Envelopes: recipient may pull/delete their own; senders may insert.
DROP POLICY IF EXISTS e2ee_envelope_select ON e2ee_message_envelopes;
DROP POLICY IF EXISTS e2ee_envelope_insert ON e2ee_message_envelopes;
DROP POLICY IF EXISTS e2ee_envelope_delete ON e2ee_message_envelopes;

CREATE POLICY e2ee_envelope_select ON e2ee_message_envelopes
    FOR SELECT TO authenticated
    USING (recipient_user_id = auth.uid());
CREATE POLICY e2ee_envelope_insert ON e2ee_message_envelopes
    FOR INSERT TO authenticated
    WITH CHECK (sender_user_id = auth.uid() OR is_sealed);
CREATE POLICY e2ee_envelope_delete ON e2ee_message_envelopes
    FOR DELETE TO authenticated
    USING (recipient_user_id = auth.uid());

-- Verification events: append-only — owner inserts and reads, no UPDATE/DELETE.
DROP POLICY IF EXISTS e2ee_verification_select ON e2ee_verification_events;
DROP POLICY IF EXISTS e2ee_verification_insert ON e2ee_verification_events;

CREATE POLICY e2ee_verification_select ON e2ee_verification_events
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());
CREATE POLICY e2ee_verification_insert ON e2ee_verification_events
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
-- Intentionally no UPDATE or DELETE policies → table is append-only.

-- Backup chunks: owner full control (we want delete-all to work).
DROP POLICY IF EXISTS e2ee_backup_owner ON e2ee_backups;
CREATE POLICY e2ee_backup_owner ON e2ee_backups
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Escrow: read-only for affected users; only org admin (service role) writes.
DROP POLICY IF EXISTS e2ee_escrow_read ON e2ee_escrow_keys;
CREATE POLICY e2ee_escrow_read ON e2ee_escrow_keys
    FOR SELECT TO authenticated USING (TRUE);

-- Handoff: owner-only; new device sees its own pending request.
DROP POLICY IF EXISTS e2ee_handoff_owner ON e2ee_handoff_requests;
CREATE POLICY e2ee_handoff_owner ON e2ee_handoff_requests
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
