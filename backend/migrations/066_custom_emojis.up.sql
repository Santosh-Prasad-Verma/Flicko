CREATE TABLE IF NOT EXISTS custom_emojis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(server_id, name)
);

CREATE INDEX IF NOT EXISTS idx_custom_emojis_server_id ON custom_emojis(server_id);
