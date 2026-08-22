# Watch Together — Schema

## Migration: `120_watch_together.sql`

```sql
-- Migration 120: Watch Together
-- Up

CREATE TABLE IF NOT EXISTS wt_sessions (
    id              text PRIMARY KEY,
    room_id         text NOT NULL,
    host_user_id    text NOT NULL,
    media_kind      text NOT NULL CHECK (media_kind IN ('youtube','vimeo','mp4','hls','appwrite')),
    media_url       text NOT NULL,
    media_title     text,
    media_duration_ms integer,
    settings        jsonb NOT NULL DEFAULT '{}'::jsonb,
    state           text NOT NULL DEFAULT 'draft'
                    CHECK (state IN ('draft','ready','playing','paused','ended')),
    anchor_position_ms integer NOT NULL DEFAULT 0,
    anchor_playing  boolean NOT NULL DEFAULT false,
    anchor_rate     numeric(3,2) NOT NULL DEFAULT 1.0,
    anchor_wall_ms  bigint NOT NULL DEFAULT 0,
    seq             integer NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    ended_at        timestamptz,
    last_active_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX wt_sessions_room_active_idx
  ON wt_sessions (room_id)
  WHERE state IN ('ready','playing','paused');

CREATE INDEX wt_sessions_host_idx ON wt_sessions (host_user_id);
CREATE INDEX wt_sessions_last_active_idx ON wt_sessions (last_active_at);

CREATE TABLE IF NOT EXISTS wt_participants (
    id              bigserial PRIMARY KEY,
    session_id      text NOT NULL REFERENCES wt_sessions(id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    role            text NOT NULL CHECK (role IN ('host','viewer')),
    joined_at       timestamptz NOT NULL DEFAULT now(),
    left_at         timestamptz,
    last_drift_ms   integer NOT NULL DEFAULT 0,
    UNIQUE (session_id, user_id)
);

CREATE INDEX wt_participants_session_idx
  ON wt_participants (session_id)
  WHERE left_at IS NULL;

CREATE INDEX wt_participants_user_active_idx
  ON wt_participants (user_id)
  WHERE left_at IS NULL;

CREATE TABLE IF NOT EXISTS wt_reactions (
    id              bigserial PRIMARY KEY,
    session_id      text NOT NULL REFERENCES wt_sessions(id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    emoji           text NOT NULL,
    position_ms     integer NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX wt_reactions_session_pos_idx
  ON wt_reactions (session_id, position_ms);

-- updated_at trigger
CREATE OR REPLACE FUNCTION wt_touch_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wt_sessions_touch
  BEFORE UPDATE ON wt_sessions
  FOR EACH ROW EXECUTE FUNCTION wt_touch_updated_at();

-- Down (rollback)
-- DROP TABLE wt_reactions;
-- DROP TABLE wt_participants;
-- DROP TABLE wt_sessions;
-- DROP FUNCTION wt_touch_updated_at;
```

## Row Level Security

```sql
ALTER TABLE wt_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE wt_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE wt_reactions ENABLE ROW LEVEL SECURITY;

-- Sessions: readable to room members; writable to host only
CREATE POLICY wt_sessions_read ON wt_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM voice_room_members m
      WHERE m.room_id = wt_sessions.room_id
        AND m.user_id = auth.uid()
    )
  );

CREATE POLICY wt_sessions_host_write ON wt_sessions
  FOR UPDATE
  USING (host_user_id = auth.uid())
  WITH CHECK (host_user_id = auth.uid());

CREATE POLICY wt_sessions_insert ON wt_sessions
  FOR INSERT
  WITH CHECK (host_user_id = auth.uid());

-- Participants: a participant can read their own session row; host can read all
CREATE POLICY wt_participants_self_read ON wt_participants
  FOR SELECT
  USING (
    user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM wt_sessions s
      WHERE s.id = wt_participants.session_id
        AND s.host_user_id = auth.uid()
    )
  );

CREATE POLICY wt_participants_self_insert ON wt_participants
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY wt_participants_self_leave ON wt_participants
  FOR UPDATE
  USING (user_id = auth.uid());

-- Reactions: any participant can post their own
CREATE POLICY wt_reactions_insert ON wt_reactions
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND EXISTS (
      SELECT 1 FROM wt_participants p
      WHERE p.session_id = wt_reactions.session_id
        AND p.user_id = auth.uid()
        AND p.left_at IS NULL
    )
  );

CREATE POLICY wt_reactions_read ON wt_reactions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM wt_participants p
      WHERE p.session_id = wt_reactions.session_id
        AND p.user_id = auth.uid()
    )
  );
```

## Redis Keys (Upstash)

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `wt:s:{id}:state` | hash | 12 h | host_id, position_ms, playing, rate, wall_ms, seq |
| `wt:s:{id}:viewers` | set | 12 h | active user_ids |
| `wt:s:{id}:host_lock` | string | 5 s | election mutex |
| `wt:room:{room_id}:sessions` | set | 12 h | active session ids |
| `wt:rate:host:{user_id}:anchors` | string (counter) | 60 s | rate-limit anchors per minute |
| `wt:rate:user:{user_id}:reactions` | string (counter) | 60 s | rate-limit reactions per minute |

Update strategy: write-through. API writes Postgres on every state-changing event, Redis is the read path for hot data and is rebuildable.

## Appwrite Storage

Bucket: `wt-uploads`
- File size cap: 250 MB on free tier; chunked upload.
- Allowed MIME: `video/mp4`, `video/webm`, `application/x-mpegURL`.
- Permissions: file owner read/write; voice-room members read via signed URL minted by Go service.
- Lifecycle: auto-purge files unreferenced by any `wt_sessions.media_url` after 30 d.

Bucket policy snippet (pseudocode):
```
read:  user:{owner}, role:room_member:{room_id}
write: user:{owner}
```

## Centrifugo Channels
- `room:{room_id}:wt` — broadcast session lifecycle (created, ended, host-changed).
- `wt:{session_id}:fallback` — used only when Azure ACS unavailable.
- `user:{user_id}:wt` — private notifications (you-are-host, you-were-kicked).
