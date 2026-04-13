-- 003_allow_system_messages_without_author.sql
-- Allow bot/system messages to omit author_id.

ALTER TABLE messages ALTER COLUMN author_id DROP NOT NULL;
