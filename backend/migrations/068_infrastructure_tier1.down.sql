ALTER TABLE messages DROP COLUMN IF EXISTS is_silent;
ALTER TABLE server_members DROP COLUMN IF EXISTS timeout_until;
ALTER TABLE attachments DROP COLUMN IF EXISTS alt_text;
