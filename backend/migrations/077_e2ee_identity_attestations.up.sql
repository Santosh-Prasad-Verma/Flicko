-- ============================================================
-- Migration 077: identity rotation attestations
-- ============================================================
--
-- When a user rotates their identity key, the OLD signing key signs a
-- statement attesting that the NEW key is the legitimate successor:
--
--     msg = "rotate:<base64(old_identity_pub)>:<base64(new_identity_pub)>"
--     sig = Ed25519(old_signing_priv, msg)
--
-- Peers fetch the attestation alongside the new identity; if the
-- signature verifies under the OLD signing key (which they already
-- pinned), the rotation is considered authenticated. The
-- IdentityChangeBanner softens its tone in that case.
--
-- A user can publish multiple attestations across their lifetime
-- (a chain). The most recent row matching `new_identity_pub` is used.
CREATE TABLE IF NOT EXISTS e2ee_identity_attestations (
    id            BIGSERIAL   PRIMARY KEY,
    user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    old_identity_pub TEXT     NOT NULL,        -- base64 X25519 pub
    new_identity_pub TEXT     NOT NULL,        -- base64 X25519 pub
    signature        TEXT     NOT NULL,        -- base64 Ed25519 sig
    attested_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_e2ee_attestation_user_new
    ON e2ee_identity_attestations (user_id, new_identity_pub);

ALTER TABLE e2ee_identity_attestations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS e2ee_attestation_read  ON e2ee_identity_attestations;
DROP POLICY IF EXISTS e2ee_attestation_write ON e2ee_identity_attestations;

-- Public-key-style table: world-readable to authenticated users.
CREATE POLICY e2ee_attestation_read  ON e2ee_identity_attestations
    FOR SELECT TO authenticated USING (TRUE);
-- Only the owning user can publish an attestation about themselves.
CREATE POLICY e2ee_attestation_write ON e2ee_identity_attestations
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
