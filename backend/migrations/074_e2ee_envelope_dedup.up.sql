-- ============================================================
-- Migration 074: E2EE envelope replay/dedup window
-- ============================================================
-- Server-side defence against envelope replay floods.
--
-- Each envelope's SHA-256(header || ciphertext) is recorded for a 7-day
-- window. Re-pushing an identical envelope to the same recipient device
-- inside that window is rejected at the relay layer, before the client
-- ever sees it.
--
-- Notes:
--   - The ciphertext alone is unique per message (DR rotates the message
--     key), so the hash collides ONLY on a true replay.
--   - The recipient's Double Ratchet would already detect replays via
--     (DHr, N) uniqueness — this layer is defence-in-depth at the relay
--     to limit DoS and to keep replay attempts out of the audit log.
--   - Window of 7 days matches `SignedPrekeyValidity` so a stale envelope
--     can no longer replay after the signed prekey it targeted has expired.

CREATE TABLE IF NOT EXISTS e2ee_envelope_dedup (
    recipient_user_id   UUID        NOT NULL,
    recipient_device_id TEXT        NOT NULL,
    message_hash        BYTEA       NOT NULL,                            -- sha256(header || ciphertext)
    seen_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (recipient_user_id, recipient_device_id, message_hash)
);

-- GC index: periodic job deletes rows older than the dedup window.
CREATE INDEX IF NOT EXISTS idx_e2ee_dedup_gc
    ON e2ee_envelope_dedup (seen_at);

-- RLS: this table is server-managed only; no client policies. The relay
-- handler runs as service role.
ALTER TABLE e2ee_envelope_dedup ENABLE ROW LEVEL SECURITY;
-- (No policies = no row visible to authenticated role; service role bypasses.)
