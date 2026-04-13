-- Create direct_messages table
CREATE TABLE direct_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  attachments JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  edited_at TIMESTAMPTZ,
  CONSTRAINT dm_content_length CHECK (char_length(content) <= 2000)
);

-- Create indexes
CREATE INDEX idx_dm_sender ON direct_messages(sender_id, created_at DESC);
CREATE INDEX idx_dm_recipient ON direct_messages(recipient_id, created_at DESC);
