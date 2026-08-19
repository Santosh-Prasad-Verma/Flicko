-- 004_rls_policies.sql

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

-- Helper function
CREATE OR REPLACE FUNCTION public.check_user_can_view_message(channel_uuid uuid, user_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.channels c
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE c.id = channel_uuid
    AND sm.user_id = user_uuid
  );
END;
$$;

-- Profiles RLS
CREATE POLICY "Profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (current_user_id() = id);

-- Servers RLS
CREATE POLICY "Users can view their servers"
  ON servers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = servers.id
      AND server_members.user_id = current_user_id()
    )
  );

CREATE POLICY "Owners can update servers"
  ON servers FOR UPDATE
  USING (owner_id = current_user_id());

CREATE POLICY "Owners can delete servers"
  ON servers FOR DELETE
  USING (owner_id = current_user_id());

CREATE POLICY "Authenticated users can create servers"
  ON servers FOR INSERT
  WITH CHECK (current_user_id() = owner_id);

-- Messages RLS
CREATE POLICY "Users can view messages in accessible channels"
  ON messages FOR SELECT
  USING (check_user_can_view_message(channel_id, current_user_id()));

CREATE POLICY "Users can send messages in accessible channels"
  ON messages FOR INSERT
  WITH CHECK (
    current_user_id() = author_id AND
    check_user_can_view_message(channel_id, current_user_id())
  );

CREATE POLICY "Users can update own messages"
  ON messages FOR UPDATE
  USING (author_id = current_user_id());

CREATE POLICY "Users can delete own messages"
  ON messages FOR DELETE
  USING (author_id = current_user_id());

-- Friends RLS
CREATE POLICY "Users can view own friendships"
  ON friends FOR SELECT
  USING (user_id = current_user_id() OR friend_id = current_user_id());

CREATE POLICY "Users can send friend requests"
  ON friends FOR INSERT
  WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can update own friendships"
  ON friends FOR UPDATE
  USING (user_id = current_user_id() OR friend_id = current_user_id());

CREATE POLICY "Users can delete own friendships"
  ON friends FOR DELETE
  USING (user_id = current_user_id() OR friend_id = current_user_id());

-- Direct Messages RLS
CREATE POLICY "Users can view own DMs"
  ON direct_messages FOR SELECT
  USING (sender_id = current_user_id() OR recipient_id = current_user_id());

CREATE POLICY "Users can send DMs"
  ON direct_messages FOR INSERT
  WITH CHECK (sender_id = current_user_id());

CREATE POLICY "Users can update own sent DMs"
  ON direct_messages FOR UPDATE
  USING (sender_id = current_user_id());

CREATE POLICY "Users can delete own sent DMs"
  ON direct_messages FOR DELETE
  USING (sender_id = current_user_id());

-- Slowmode Helper & Restrictive Policy
CREATE OR REPLACE FUNCTION check_slowmode_allowed(p_channel_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_slowmode_delay    INT;
    v_last_message_time TIMESTAMPTZ;
    v_is_moderator      BOOLEAN;
BEGIN
    SELECT slowmode_seconds INTO v_slowmode_delay
    FROM channels
    WHERE id = p_channel_id;

    IF v_slowmode_delay IS NULL OR v_slowmode_delay = 0 THEN
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

CREATE POLICY enforce_slowmode_on_send ON messages
    AS RESTRICTIVE
    FOR INSERT
    WITH CHECK (check_slowmode_allowed(channel_id, current_user_id()));

-- Advanced RLS
ALTER TABLE soundboard_sounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE soundboard_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Server members can view soundboard sounds"
  ON soundboard_sounds FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = soundboard_sounds.server_id
        AND server_members.user_id = current_user_id()
    )
  );

CREATE POLICY "Server members can insert soundboard sounds"
  ON soundboard_sounds FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = soundboard_sounds.server_id
        AND server_members.user_id = current_user_id()
    )
  );

CREATE POLICY "Uploaders or admins can delete soundboard sounds"
  ON soundboard_sounds FOR DELETE
  USING (
    uploaded_by = current_user_id()
    OR EXISTS (
      SELECT 1 FROM servers
      WHERE servers.id = soundboard_sounds.server_id
        AND servers.owner_id = current_user_id()
    )
  );

CREATE POLICY "Users manage own favorites"
  ON soundboard_favorites FOR ALL
  USING (user_id = current_user_id())
  WITH CHECK (user_id = current_user_id());

CREATE POLICY "Anyone can view activities"
  ON activities FOR SELECT
  USING (true);

CREATE POLICY "Server members can view activity sessions"
  ON activity_sessions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = activity_sessions.server_id
        AND server_members.user_id = current_user_id()
    )
  );

CREATE POLICY "Server members can create activity sessions"
  ON activity_sessions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = activity_sessions.server_id
        AND server_members.user_id = current_user_id()
    )
  );

CREATE POLICY "Host can update activity sessions"
  ON activity_sessions FOR UPDATE
  USING (host_user_id = current_user_id());

CREATE POLICY "Host can delete activity sessions"
  ON activity_sessions FOR DELETE
  USING (host_user_id = current_user_id());

CREATE POLICY "Server members can view activity participants"
  ON activity_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM activity_sessions AS s
      JOIN server_members AS sm ON sm.server_id = s.server_id
      WHERE s.id = activity_participants.session_id
        AND sm.user_id = current_user_id()
    )
  );

CREATE POLICY "Users can join activity sessions"
  ON activity_participants FOR INSERT
  WITH CHECK (user_id = current_user_id());

CREATE POLICY "Users can leave activity sessions"
  ON activity_participants FOR DELETE
  USING (user_id = current_user_id());
