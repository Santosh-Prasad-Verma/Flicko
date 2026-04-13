-- Enable Row Level Security on servers table
ALTER TABLE servers ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their servers
-- Allows users to view servers where they are members
CREATE POLICY "Users can view their servers"
  ON servers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = servers.id
      AND server_members.user_id = auth.uid()
    )
  );

-- Policy: Owners can update servers
-- Allows server owners to update their server settings
CREATE POLICY "Owners can update servers"
  ON servers FOR UPDATE
  USING (owner_id = auth.uid());

-- Policy: Owners can delete servers
-- Allows server owners to delete their servers
CREATE POLICY "Owners can delete servers"
  ON servers FOR DELETE
  USING (owner_id = auth.uid());

-- Policy: Authenticated users can create servers
-- Allows authenticated users to create new servers where they are the owner
CREATE POLICY "Authenticated users can create servers"
  ON servers FOR INSERT
  WITH CHECK (auth.uid() = owner_id);
