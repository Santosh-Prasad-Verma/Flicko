-- ============================================================
-- Migration 075: per-device DM envelopes (multi-device fan-out)
-- ============================================================
-- Today, `direct_messages` stores ONE inline ciphertext per row, which means
-- only one of a recipient's devices can decrypt the message. To support
-- multi-device delivery (phone + laptop + tablet) we move the ciphertext
-- into a child table with one row per (message, recipient_device).
--
-- Migration strategy:
--   1. Create `dm_message_envelopes` (this migration).
--   2. Backfill existing v1/v2 rows: copy each row's inline ciphertext into
--      a single envelope row addressed to its `recipient_device_id`.
--   3. The legacy ciphertext columns on `direct_messages` stay in place for
--      now so old clients can still read; a follow-up migration can drop
--      them once 100% of clients ship the new read path.
--
-- The DM row remains the source of truth for metadata (sender, recipient,
-- timestamps, attachments, reactions). Envelopes hold only the per-device
-- crypto payload.

CREATE TABLE IF NOT EXISTS dm_message_envelopes (
    id                   BIGSERIAL   PRIMARY KEY,
    message_id           UUID        NOT NULL REFERENCES direct_messages(id) ON DELETE CASCADE,
    recipient_device_id  TEXT        NOT NULL,
    sender_device_id     TEXT        NOT NULL,

    -- Crypto payload (v2: header + ciphertext are populated; nonce is empty).
    -- v1 backfill: nonce, sender_ephemeral_pub, prekey_id, signed_prekey_id
    -- are populated; ratchet_header is null.
    protocol_version     TEXT        NOT NULL CHECK (protocol_version IN ('v1','v2')),
    ciphertext           TEXT        NOT NULL,                          -- base64
    nonce                TEXT,                                          -- v1 only
    ratchet_header       TEXT,                                          -- v2 only
    sender_ephemeral_pub TEXT,                                          -- v1 every msg, v2 initial only
    sender_identity_pub  TEXT,                                          -- v2 initial only
    is_initial           BOOLEAN     NOT NULL DEFAULT FALSE,            -- v2 X3DH bootstrap
    prekey_id            INT,
    signed_prekey_id     INT,

    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (message_id, recipient_device_id)
);

CREATE INDEX IF NOT EXISTS idx_dm_envelopes_message
    ON dm_message_envelopes (message_id);

-- Hot path: a device fetches its envelopes for messages it can see.
-- Combined with a JOIN against direct_messages.recipient_id, this lets
-- each device read only the envelopes addressed to it.
CREATE INDEX IF NOT EXISTS idx_dm_envelopes_device
    ON dm_message_envelopes (recipient_device_id, message_id);

-- ── Backfill existing rows ───────────────────────────────────────────────────
-- Copy the inline ciphertext from `direct_messages` into the new table for
-- every encrypted row that has a recipient_device_id. v1 envelopes always
-- carry nonce + sender_ephemeral_pub; their protocol_version is 'v1'.
INSERT INTO dm_message_envelopes (
    message_id, recipient_device_id, sender_device_id,
    protocol_version, ciphertext, nonce, sender_ephemeral_pub,
    prekey_id, signed_prekey_id, created_at
)
SELECT
    id,
    recipient_device_id,
    COALESCE(sender_device_id, ''),
    'v1',
    ciphertext,
    nonce,
    sender_ephemeral_pub,
    prekey_id,
    signed_prekey_id,
    created_at
FROM direct_messages
WHERE is_encrypted = TRUE
  AND ciphertext IS NOT NULL
  AND recipient_device_id IS NOT NULL
ON CONFLICT (message_id, recipient_device_id) DO NOTHING;

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE dm_message_envelopes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dm_envelopes_select ON dm_message_envelopes;
DROP POLICY IF EXISTS dm_envelopes_insert ON dm_message_envelopes;

-- Recipients can read envelopes for messages addressed to them. We don't
-- restrict by device at the SQL layer (the DM row already restricts to the
-- recipient user); the client filters by its own device id.
CREATE POLICY dm_envelopes_select ON dm_message_envelopes
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM direct_messages dm
            WHERE dm.id = dm_message_envelopes.message_id
              AND (dm.sender_id = auth.uid() OR dm.recipient_id = auth.uid())
        )
    );

-- Senders insert one row per recipient device when they send a message.
CREATE POLICY dm_envelopes_insert ON dm_message_envelopes
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM direct_messages dm
            WHERE dm.id = dm_message_envelopes.message_id
              AND dm.sender_id = auth.uid()
        )
    );
