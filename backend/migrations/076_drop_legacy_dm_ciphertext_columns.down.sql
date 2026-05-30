-- ============================================================
-- Migration 076 (down): re-add legacy inline DM ciphertext columns
-- ============================================================
--
-- Restores the columns as nullable. Historical ciphertext content cannot
-- be recovered from this rollback — it survives only inside the
-- `dm_message_envelopes` child table.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'direct_messages') THEN
        ALTER TABLE direct_messages
            ADD COLUMN IF NOT EXISTS ciphertext           TEXT,
            ADD COLUMN IF NOT EXISTS nonce                TEXT,
            ADD COLUMN IF NOT EXISTS sender_ephemeral_pub TEXT,
            ADD COLUMN IF NOT EXISTS sender_device_id     TEXT,
            ADD COLUMN IF NOT EXISTS recipient_device_id  TEXT,
            ADD COLUMN IF NOT EXISTS prekey_id            INT,
            ADD COLUMN IF NOT EXISTS signed_prekey_id     INT;
    END IF;
END$$;
