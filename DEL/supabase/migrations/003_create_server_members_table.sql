-- Create server_members table
CREATE TABLE server_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  nickname TEXT,
  roles UUID[] DEFAULT '{}',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  communication_disabled_until TIMESTAMPTZ,
  UNIQUE(server_id, user_id)
);

-- Create indexes
CREATE INDEX idx_server_members_server ON server_members(server_id);
CREATE INDEX idx_server_members_user ON server_members(user_id);
