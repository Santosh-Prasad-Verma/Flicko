-- Migration: 046 Utility RPC functions
-- Creates helper functions called from the mobile app.

-- Get mutual servers between two users
CREATE OR REPLACE FUNCTION get_mutual_servers(user_a UUID, user_b UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    icon TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT s.id, s.name, s.icon
    FROM servers s
    INNER JOIN server_members ma ON ma.server_id = s.id AND ma.user_id = user_a
    INNER JOIN server_members mb ON mb.server_id = s.id AND mb.user_id = user_b
    ORDER BY s.name;
$$;

-- Full-text search on messages (ts_vector approach if available, falls back to ILIKE)
-- This creates a GIN index on message content for fast search.
DO $$
BEGIN
    -- Add tsvector column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'messages' AND column_name = 'content_tsv'
    ) THEN
        ALTER TABLE messages ADD COLUMN content_tsv tsvector
            GENERATED ALWAYS AS (to_tsvector('english', COALESCE(content, ''))) STORED;
        CREATE INDEX IF NOT EXISTS idx_messages_content_tsv ON messages USING GIN (content_tsv);
    END IF;
END
$$;

-- Count unread messages for a user across all channels
CREATE OR REPLACE FUNCTION get_unread_counts(p_user_id UUID)
RETURNS TABLE (
    channel_id UUID,
    unread_count BIGINT,
    mention_count INT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        rs.channel_id,
        COALESCE(
            (SELECT COUNT(*) FROM messages m
             WHERE m.channel_id = rs.channel_id
               AND m.created_at > COALESCE(rs.updated_at, '1970-01-01'::timestamptz)
               AND m.author_id != p_user_id),
            0
        ) AS unread_count,
        rs.mention_count
    FROM channel_read_states rs
    WHERE rs.user_id = p_user_id;
$$;
