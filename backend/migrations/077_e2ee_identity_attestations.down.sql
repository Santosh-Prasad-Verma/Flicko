DROP POLICY IF EXISTS e2ee_attestation_write ON e2ee_identity_attestations;
DROP POLICY IF EXISTS e2ee_attestation_read  ON e2ee_identity_attestations;
DROP INDEX IF EXISTS idx_e2ee_attestation_user_new;
DROP TABLE IF EXISTS e2ee_identity_attestations;
