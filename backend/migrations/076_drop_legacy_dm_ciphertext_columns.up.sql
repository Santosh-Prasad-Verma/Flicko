-- ============================================================
-- Migration 076: drop legacy inline DM ciphertext columns
-- ============================================================
--
-- ⚠️ DO NOT DEPLOY UNTIL BOTH ARE TRUE:
--   1. 100% of mobile clients ship the per-device read path that lives in
--      `dm_repository.dart` (the path that joins `dm_message_envelopes` and
--      ignores the inline columns). Track via app-version analytics; allow
--      ≥ 2 weeks past the minimum-supported-version cut.
--   2. Operations have a verified 075 backfill: every `direct_messages`
--      row with `is_encrypted = TRUE` has a matching row in
--      `dm_message_envelopes`. Run the audit query at the bottom of this
--      file BEFORE applying.
--
-- This migration drops:
--   - direct_messages.ciphertext
--   - direct_messages.nonce
--   - direct_messages.sender_ephemeral_pub
--   - direct_messages.sender_device_id
--   - direct_messages.recipient_device_id
--   - direct_messages.prekey_id
--   - direct_messages.signed_prekey_id
--
-- After this point the only path to read a ciphertext is via the
-- `dm_message_envelopes` child table. There is no rollback once data is
-- gone — the .down.sql restores the columns as nullable, but historical
-- ciphertext content cannot be recovered from the children alone (it can
-- be re-derived for messages whose backfill ran in 075, which is why the
-- pre-flight audit matters).
--
-- ── Pre-flight audit (run manually, expect zero rows) ───────────────────────
-- SELECT dm.id
-- FROM   direct_messages dm
-- LEFT JOIN dm_message_envelopes env ON env.message_id = dm.id
-- WHERE  dm.is_encrypted = TRUE
-- AND    env.id IS NULL;
--
-- ── Migration ───────────────────────────────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'direct_messages') THEN
        ALTER TABLE direct_messages
            DROP COLUMN IF EXISTS ciphertext,
            DROP COLUMN IF EXISTS nonce,
            DROP COLUMN IF EXISTS sender_ephemeral_pub,
            DROP COLUMN IF EXISTS sender_device_id,
            DROP COLUMN IF EXISTS recipient_device_id,
            DROP COLUMN IF EXISTS prekey_id,
            DROP COLUMN IF EXISTS signed_prekey_id;
    END IF;
END$$;
