-- Rollback Migration 072

DROP VIEW IF EXISTS e2ee_latest_signed_prekey;

DROP TABLE IF EXISTS e2ee_conversation_state;
DROP TABLE IF EXISTS e2ee_one_time_prekeys;
DROP TABLE IF EXISTS e2ee_signed_prekeys;
DROP TABLE IF EXISTS e2ee_identity_keys;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'direct_messages') THEN
        ALTER TABLE direct_messages
            DROP COLUMN IF EXISTS is_encrypted,
            DROP COLUMN IF EXISTS ciphertext,
            DROP COLUMN IF EXISTS nonce,
            DROP COLUMN IF EXISTS sender_ephemeral_pub,
            DROP COLUMN IF EXISTS sender_device_id,
            DROP COLUMN IF EXISTS recipient_device_id,
            DROP COLUMN IF EXISTS prekey_id,
            DROP COLUMN IF EXISTS signed_prekey_id;
    END IF;
END$$;
