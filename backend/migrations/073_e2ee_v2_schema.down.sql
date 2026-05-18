-- Rollback Migration 073 — return to v1-only schema state.

DROP POLICY IF EXISTS e2ee_handoff_owner       ON e2ee_handoff_requests;
DROP POLICY IF EXISTS e2ee_escrow_read         ON e2ee_escrow_keys;
DROP POLICY IF EXISTS e2ee_backup_owner        ON e2ee_backups;
DROP POLICY IF EXISTS e2ee_verification_insert ON e2ee_verification_events;
DROP POLICY IF EXISTS e2ee_verification_select ON e2ee_verification_events;
DROP POLICY IF EXISTS e2ee_envelope_delete     ON e2ee_message_envelopes;
DROP POLICY IF EXISTS e2ee_envelope_insert     ON e2ee_message_envelopes;
DROP POLICY IF EXISTS e2ee_envelope_select     ON e2ee_message_envelopes;

DROP TABLE IF EXISTS e2ee_handoff_requests;
DROP TABLE IF EXISTS e2ee_escrow_keys;
DROP TABLE IF EXISTS e2ee_backups;
DROP TABLE IF EXISTS e2ee_verification_events;
DROP TABLE IF EXISTS e2ee_message_envelopes;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name='direct_messages' AND column_name='e2ee_protocol_version') THEN
        ALTER TABLE direct_messages DROP COLUMN e2ee_protocol_version;
    END IF;
END$$;
