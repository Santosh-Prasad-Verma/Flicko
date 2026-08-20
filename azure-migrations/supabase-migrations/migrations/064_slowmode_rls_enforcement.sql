-- 064_slowmode_rls_enforcement.sql
--
-- Enforce slowmode on the messages table at the DB layer and expose a helper
-- so the UI can show a per-channel countdown.
--
-- NOTE: An earlier version of this file referenced messages.user_id (the
-- column is author_id), used member_roles.member_id (the column is user_id),
-- and used single-$ instead of $$ as the function-body delimiter, all of
-- which caused the migration to abort and silently skip every later
-- migration in the chain. Fixed below.

-- 1. Partial index for fast lookups of recent messages by channel and author.
CREATE INDEX IF NOT EXISTS idx_messages_slowmode_lookup
  ON messages (channel_id, author_id, created_at DESC);

-- 2. Function to check if a send is allowed under the channel's slowmode.
CREATE OR REPLACE FUNCTION check_slowmode_allowed(p_channel_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_slowmode_delay    INT;
    v_last_message_time TIMESTAMPTZ;
    v_is_moderator      BOOLEAN;
BEGIN
    -- Get channel slowmode setting.
    SELECT slowmode_seconds INTO v_slowmode_delay
    FROM channels
    WHERE id = p_channel_id;

    -- No slowmode configured: allow.
    IF v_slowmode_delay IS NULL OR v_slowmode_delay = 0 THEN
        RETURN TRUE;
    END IF;

    -- Moderators (MANAGE_MESSAGES) bypass slowmode.
    SELECT EXISTS (
        SELECT 1
        FROM server_members sm
        JOIN member_roles mr ON mr.user_id = sm.user_id
                            AND mr.server_id = sm.server_id
        JOIN roles r         ON r.id = mr.role_id
        WHERE sm.server_id = (SELECT server_id FROM channels WHERE id = p_channel_id)
          AND sm.user_id = p_user_id
          AND (r.permissions & (1 << 13)) != 0  -- MANAGE_MESSAGES bit
    ) INTO v_is_moderator;

    IF v_is_moderator THEN
        RETURN TRUE;
    END IF;

    -- Time of this user's last message in this channel.
    SELECT created_at INTO v_last_message_time
    FROM messages
    WHERE channel_id = p_channel_id AND author_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_message_time IS NULL THEN
        RETURN TRUE;
    END IF;

    RETURN EXTRACT(EPOCH FROM (now() - v_last_message_time)) >= v_slowmode_delay;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Restrictive RLS policy that AND's slowmode onto the existing send rules
--    in 015_messages_rls_policies.sql. Without RESTRICTIVE, this policy would
--    be OR'd with the permissive insert policy and never actually block.
DROP POLICY IF EXISTS enforce_slowmode_on_send ON messages;
CREATE POLICY enforce_slowmode_on_send ON messages
    AS RESTRICTIVE
    FOR INSERT
    WITH CHECK (check_slowmode_allowed(channel_id, auth.uid()));

-- 4. Helper for the UI to show remaining cooldown for the current user.
CREATE OR REPLACE FUNCTION get_slowmode_remaining_seconds(p_channel_id UUID)
RETURNS INT AS $$
DECLARE
    v_slowmode_delay    INT;
    v_last_message_time TIMESTAMPTZ;
    v_remaining_seconds INT;
BEGIN
    SELECT slowmode_seconds INTO v_slowmode_delay
    FROM channels
    WHERE id = p_channel_id;

    IF v_slowmode_delay IS NULL OR v_slowmode_delay = 0 THEN
        RETURN 0;
    END IF;

    SELECT created_at INTO v_last_message_time
    FROM messages
    WHERE channel_id = p_channel_id AND author_id = auth.uid()
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_message_time IS NULL THEN
        RETURN 0;
    END IF;

    v_remaining_seconds := v_slowmode_delay
        - EXTRACT(EPOCH FROM (now() - v_last_message_time))::INT;

    RETURN GREATEST(v_remaining_seconds, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
