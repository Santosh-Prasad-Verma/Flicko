CREATE TABLE IF NOT EXISTS dm_webrtc_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL, -- offer, answer, ice_candidate, end_call
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Realtime publication setup for the table to stream inserts (if publication exists)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE dm_webrtc_signals;
    END IF;
END $$;

CREATE INDEX idx_webrtc_receiver ON dm_webrtc_signals(receiver_id);
CREATE INDEX idx_webrtc_channel ON dm_webrtc_signals(channel_id);
