-- ============================================================
-- Migration 075 (down): drop dm_message_envelopes
-- ============================================================
DROP POLICY IF EXISTS dm_envelopes_select  ON dm_message_envelopes;
DROP POLICY IF EXISTS dm_envelopes_insert  ON dm_message_envelopes;
DROP INDEX IF EXISTS idx_dm_envelopes_device;
DROP INDEX IF EXISTS idx_dm_envelopes_message;
DROP TABLE IF EXISTS dm_message_envelopes;
