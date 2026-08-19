-- Create roles table
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT,
  permissions BIGINT DEFAULT 0,
  position INTEGER DEFAULT 0,
  hoist BOOLEAN DEFAULT FALSE,
  mentionable BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_roles_server ON roles(server_id);
