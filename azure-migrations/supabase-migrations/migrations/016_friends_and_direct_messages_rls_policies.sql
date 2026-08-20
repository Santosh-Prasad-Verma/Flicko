-- Enable Row Level Security on friends table
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view own friendships
-- Allows users to view friendships where they are either the user or the friend
CREATE POLICY "Users can view own friendships"
  ON friends FOR SELECT
  USING (user_id = auth.uid() OR friend_id = auth.uid());

-- Policy: Users can send friend requests
-- Allows users to create friend requests where they are the sender
CREATE POLICY "Users can send friend requests"
  ON friends FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Policy: Users can update own friendships
-- Allows users to update friendships they are part of (e.g., accepting requests)
CREATE POLICY "Users can update own friendships"
  ON friends FOR UPDATE
  USING (user_id = auth.uid() OR friend_id = auth.uid());

-- Policy: Users can delete own friendships
-- Allows users to delete friendships they are part of
CREATE POLICY "Users can delete own friendships"
  ON friends FOR DELETE
  USING (user_id = auth.uid() OR friend_id = auth.uid());

-- Enable Row Level Security on direct_messages table
ALTER TABLE direct_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view own DMs
-- Allows users to view direct messages they sent or received
CREATE POLICY "Users can view own DMs"
  ON direct_messages FOR SELECT
  USING (sender_id = auth.uid() OR recipient_id = auth.uid());

-- Policy: Users can send DMs
-- Allows users to send direct messages where they are the sender
CREATE POLICY "Users can send DMs"
  ON direct_messages FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- Policy: Users can update own sent DMs
-- Allows users to update direct messages they sent
CREATE POLICY "Users can update own sent DMs"
  ON direct_messages FOR UPDATE
  USING (sender_id = auth.uid());

-- Policy: Users can delete own sent DMs
-- Allows users to delete direct messages they sent
CREATE POLICY "Users can delete own sent DMs"
  ON direct_messages FOR DELETE
  USING (sender_id = auth.uid());
