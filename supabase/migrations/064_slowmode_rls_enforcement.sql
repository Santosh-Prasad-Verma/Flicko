-- 064_slowmode_rls_enforcement.sql

-- 1. Partial index for fast lookups of recent messages by channel and user
CREATE INDEX IF NOT EXISTS idx_messages_slowmode_lookup 
ON messages (channel_id, user_id, created_at DESC);

-- 2. Function to check if slowmode is allowed
CREATE OR REPLACE FUNCTION check_slowmode_allowed(p_channel_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_slowmode_delay INT;
    v_last_message_time TIMESTAMP WITH TIME ZONE;
    v_is_moderator BOOLEAN;
BEGIN
    -- Get channel slowmode setting
    SELECT slowmode_seconds INTO v_slowmode_delay
    FROM channels
    WHERE id = p_channel_id;

    -- If no slowmode or 0, allowed
    IF v_slowmode_delay IS NULL OR v_slowmode_delay = 0 THEN
        return TRUE;
    END IF;

    -- Check if user is a moderator (bypass slowmode)
    SELECT EXISTS (
        SELECT 1 FROM server_members sm
        JOIN member_roles mr ON mr.member_id = sm.user_id AND mr.server_id = sm.server_id
        JOIN roles r ON r.id = mr.role_id
        WHERE sm.server_id = (SELECT server_id FROM channels WHERE id = p_channel_id)
          AND sm.user_id = p_user_id
          AND (r.permissions & (1 << 13)) != 0  -- MANAGE_MESSAGES bit
    ) INTO v_is_moderator;

    IF v_is_moderator THEN
        return TRUE;
    END IF;

    -- Find the last message by this user in this channel
    SELECT created_at INTO v_last_message_time
    FROM messages
    WHERE channel_id = p_channel_id AND user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    -- If no previous message, allowed
    IF v_last_message_time IS NULL THEN
        return TRUE;
    END IF;

    -- If the time since the last message is greater than the slowmode delay, allowed
    IF EXTRACT(EPOCH FROM (now() - v_last_message_time)) >= v_slowmode_delay THEN
        return TRUE;
    END IF;

    -- Otherwise, blocked
    return FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RLS policy to enforce slowmode on send (inserts)
-- Assuming the table 'messages' has RLS enabled
DROP POLICY IF EXISTS enforce_slowmode_on_send ON messages;
CREATE POLICY enforce_slowmode_on_send ON messages
    FOR INSERT
    WITH CHECK (
        -- existing checks (like user must belong to channel) should remain,
        -- but this adds the slowmode enforcement
        check_slowmode_allowed(channel_id, auth.uid())
    );

-- 4. Function to get remaining slowmode seconds for the UI
CREATE OR REPLACE FUNCTION get_slowmode_remaining_seconds(p_channel_id UUID)
RETURNS INT AS $$
DECLARE
    v_slowmode_delay INT;
    v_last_message_time TIMESTAMP WITH TIME ZONE;
    v_remaining_seconds INT;
BEGIN
    -- Get channel slowmode setting
    SELECT slowmode_seconds INTO v_slowmode_delay
    FROM channels
    WHERE id = p_channel_id;

    IF v_slowmode_delay IS NULL OR v_slowmode_delay = 0 THEN
        return 0;
    END IF;

    -- Find the last message by current user in this channel
    SELECT created_at INTO v_last_message_time
    FROM messages
    WHERE channel_id = p_channel_id AND user_id = auth.uid()
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_message_time IS NULL THEN
        return 0;
    END IF;

    -- Calculate remaining seconds
    v_remaining_seconds := v_slowmode_delay - EXTRACT(EPOCH FROM (now() - v_last_message_time))::INT;

    IF v_remaining_seconds < 0 THEN
        return 0;
    END IF;

    return v_remaining_seconds;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
