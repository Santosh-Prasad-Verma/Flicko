-- Enable Row Level Security on messages table
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view messages in accessible channels
-- Allows users to view messages only in channels within servers they are members of
CREATE POLICY "Users can view messages in accessible channels"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM channels
      JOIN server_members ON channels.server_id = server_members.server_id
      WHERE channels.id = messages.channel_id
      AND server_members.user_id = auth.uid()
    )
  );

-- Policy: Users can send messages in accessible channels
-- Allows users to send messages only in channels within servers they are members of
CREATE POLICY "Users can send messages in accessible channels"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = author_id AND
    EXISTS (
      SELECT 1 FROM channels
      JOIN server_members ON channels.server_id = server_members.server_id
      WHERE channels.id = messages.channel_id
      AND server_members.user_id = auth.uid()
    )
  );

-- Policy: Users can update own messages
-- Allows users to update only their own messages
CREATE POLICY "Users can update own messages"
  ON messages FOR UPDATE
  USING (author_id = auth.uid());

-- Policy: Users can delete own messages
-- Allows users to delete only their own messages
CREATE POLICY "Users can delete own messages"
  ON messages FOR DELETE
  USING (author_id = auth.uid());
