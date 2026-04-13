-- Silent Messages
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_silent BOOLEAN DEFAULT false;

-- User Timeout
ALTER TABLE server_members ADD COLUMN IF NOT EXISTS timeout_until TIMESTAMPTZ NULL;

-- Image Alt Text
ALTER TABLE attachments ADD COLUMN IF NOT EXISTS alt_text TEXT NULL;
