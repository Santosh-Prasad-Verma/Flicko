-- Helper function to check if user can view/send messages in a channel (bypasses RLS join limitation for Realtime)
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

-- Enable Row Level Security on messages table
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view messages in accessible channels
-- Allows users to view messages only in channels within servers they are members of
CREATE POLICY "Users can view messages in accessible channels"
  ON messages FOR SELECT
  USING (check_user_can_view_message(channel_id, auth.uid()));

-- Policy: Users can send messages in accessible channels
-- Allows users to send messages only in channels within servers they are members of
CREATE POLICY "Users can send messages in accessible channels"
  ON messages FOR INSERT
  WITH CHECK (
    auth.uid() = author_id AND
    check_user_can_view_message(channel_id, auth.uid())
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

