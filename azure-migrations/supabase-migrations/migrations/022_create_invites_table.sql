-- Create invites table for server invite management
CREATE TABLE invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ,
  max_uses INTEGER,
  uses INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_invites_server ON invites(server_id);
CREATE INDEX idx_invites_code ON invites(code);
CREATE INDEX idx_invites_created_by ON invites(created_by);

-- Add RLS policies
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view invites for servers they are members of
CREATE POLICY "Users can view invites for their servers"
  ON invites FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members
      WHERE server_members.server_id = invites.server_id
      AND server_members.user_id = auth.uid()
    )
  );

-- Policy: Server owners can create invites
CREATE POLICY "Server owners can create invites"
  ON invites FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM servers
      WHERE servers.id = invites.server_id
      AND servers.owner_id = auth.uid()
    )
  );

-- Policy: Server owners can delete invites
CREATE POLICY "Server owners can delete invites"
  ON invites FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM servers
      WHERE servers.id = invites.server_id
      AND servers.owner_id = auth.uid()
    )
  );

-- Policy: Anyone can view invite by code (for joining)
CREATE POLICY "Anyone can view invite by code"
  ON invites FOR SELECT
  USING (true);
