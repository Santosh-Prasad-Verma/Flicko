-- 061_create_dm_calls.sql

CREATE TABLE IF NOT EXISTS dm_calls (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id   uuid        NOT NULL REFERENCES direct_messages(id) ON DELETE CASCADE,
  initiator_id      uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  call_type         text        NOT NULL DEFAULT 'audio'
                                CHECK (call_type IN ('audio', 'video')),
  status            text        NOT NULL DEFAULT 'ringing'
                                CHECK (status IN ('ringing', 'active', 'ended', 'missed', 'declined')),
  participants      uuid[]      NOT NULL DEFAULT '{}',
  started_at        timestamptz,
  ended_at          timestamptz,
  duration_seconds  integer     GENERATED ALWAYS AS (
    CASE WHEN ended_at IS NOT NULL AND started_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM ended_at - started_at)::integer
      ELSE NULL
    END
  ) STORED,
  created_at        timestamptz NOT NULL DEFAULT now(),

  -- Auto-miss calls after 60 seconds of ringing
  ring_deadline     timestamptz NOT NULL DEFAULT (now() + interval '60 seconds')
);

CREATE INDEX IF NOT EXISTS idx_dm_calls_conversation ON dm_calls (conversation_id)
  WHERE status IN ('ringing', 'active');

CREATE INDEX IF NOT EXISTS idx_dm_calls_ringing ON dm_calls (ring_deadline)
  WHERE status = 'ringing';

-- Auto-expire ringing calls
CREATE OR REPLACE FUNCTION expire_ringing_calls()
RETURNS void AS $$
BEGIN
  UPDATE dm_calls
  SET status = 'missed', ended_at = NOW()
  WHERE status = 'ringing' AND ring_deadline < NOW();
END;
$$ LANGUAGE plpgsql;

-- RLS
ALTER TABLE dm_calls ENABLE ROW LEVEL SECURITY;

CREATE POLICY dm_calls_participants ON dm_calls
  FOR ALL USING (
    initiator_id = auth.uid()
    OR auth.uid() = ANY(participants)
    OR EXISTS (
      SELECT 1 FROM dm_participants
      WHERE conversation_id = dm_calls.conversation_id
        AND user_id = auth.uid()
    )
  );
