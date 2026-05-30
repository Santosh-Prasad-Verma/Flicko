# Music Party — Schema

## Migration: `121_music_party.sql`

```sql
-- Migration 121: Music Party
-- Up

CREATE TABLE IF NOT EXISTS mp_sessions (
    id              text PRIMARY KEY,
    room_id         text NOT NULL,
    dj_user_id      text NOT NULL,
    next_dj_user_id text,
    rotation_mode   text NOT NULL DEFAULT 'manual'
                    CHECK (rotation_mode IN ('manual','round_robin','listener_vote')),
    state           text NOT NULL DEFAULT 'draft'
                    CHECK (state IN ('draft','ready','playing','paused','ended','degraded')),
    current_track_uri text,
    current_position_ms integer NOT NULL DEFAULT 0,
    current_started_at  timestamptz,
    anchor_wall_ms  bigint NOT NULL DEFAULT 0,
    seq             integer NOT NULL DEFAULT 0,
    settings        jsonb NOT NULL DEFAULT '{
                      "vote_skip_threshold": 0.5,
                      "max_listeners": 25,
                      "allow_dupes": true
                    }'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    ended_at        timestamptz,
    last_active_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX mp_sessions_room_active_idx
  ON mp_sessions (room_id)
  WHERE state IN ('ready','playing','paused','degraded');

CREATE INDEX mp_sessions_dj_idx ON mp_sessions (dj_user_id);

CREATE TABLE IF NOT EXISTS mp_participants (
    id              bigserial PRIMARY KEY,
    session_id      text NOT NULL REFERENCES mp_sessions(id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    role            text NOT NULL CHECK (role IN ('dj','listener')),
    spotify_tier    text CHECK (spotify_tier IN ('premium','free','none')),
    joined_at       timestamptz NOT NULL DEFAULT now(),
    left_at         timestamptz,
    UNIQUE (session_id, user_id)
);

CREATE INDEX mp_participants_session_idx
  ON mp_participants (session_id)
  WHERE left_at IS NULL;

CREATE TABLE IF NOT EXISTS mp_queue (
    id              text PRIMARY KEY,
    session_id      text NOT NULL REFERENCES mp_sessions(id) ON DELETE CASCADE,
    spotify_uri     text NOT NULL,
    title           text,
    artist          text,
    duration_ms     integer,
    album_art_url   text,
    preview_url     text,
    added_by_user_id text NOT NULL,
    position        double precision NOT NULL,
    state           text NOT NULL DEFAULT 'queued'
                    CHECK (state IN ('queued','playing','completed','skipped','removed')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    played_at       timestamptz,
    ended_at        timestamptz
);

CREATE INDEX mp_queue_session_position_idx
  ON mp_queue (session_id, position)
  WHERE state = 'queued';

CREATE INDEX mp_queue_session_state_idx
  ON mp_queue (session_id, state);

CREATE TABLE IF NOT EXISTS mp_vibes (
    id              bigserial PRIMARY KEY,
    session_id      text NOT NULL REFERENCES mp_sessions(id) ON DELETE CASCADE,
    queue_item_id   text REFERENCES mp_queue(id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    kind            text NOT NULL CHECK (kind IN ('heart','fire','star','skip_vote')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (queue_item_id, user_id, kind)
);

CREATE INDEX mp_vibes_session_idx ON mp_vibes (session_id);

CREATE TABLE IF NOT EXISTS spotify_tokens (
    user_id         text PRIMARY KEY,
    access_token    bytea NOT NULL,
    refresh_token   bytea NOT NULL,
    expires_at      timestamptz NOT NULL,
    scope           text NOT NULL,
    tier            text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION mp_touch_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mp_sessions_touch
  BEFORE UPDATE ON mp_sessions
  FOR EACH ROW EXECUTE FUNCTION mp_touch_updated_at();

CREATE TRIGGER spotify_tokens_touch
  BEFORE UPDATE ON spotify_tokens
  FOR EACH ROW EXECUTE FUNCTION mp_touch_updated_at();

-- Down
-- DROP TABLE mp_vibes;
-- DROP TABLE mp_queue;
-- DROP TABLE mp_participants;
-- DROP TABLE mp_sessions;
-- DROP TABLE spotify_tokens;
-- DROP FUNCTION mp_touch_updated_at;
```

## Row Level Security

```sql
ALTER TABLE mp_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mp_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE mp_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE mp_vibes ENABLE ROW LEVEL SECURITY;
ALTER TABLE spotify_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY mp_sessions_room_member_read ON mp_sessions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM voice_room_members m
      WHERE m.room_id = mp_sessions.room_id AND m.user_id = auth.uid()
    )
  );

CREATE POLICY mp_sessions_dj_write ON mp_sessions
  FOR UPDATE
  USING (dj_user_id = auth.uid())
  WITH CHECK (dj_user_id = auth.uid());

CREATE POLICY mp_sessions_insert ON mp_sessions
  FOR INSERT
  WITH CHECK (dj_user_id = auth.uid());

CREATE POLICY mp_participants_self ON mp_participants
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY mp_queue_session_member_read ON mp_queue
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM mp_participants p
      WHERE p.session_id = mp_queue.session_id AND p.user_id = auth.uid()
    )
  );

CREATE POLICY mp_queue_member_insert ON mp_queue
  FOR INSERT
  WITH CHECK (
    added_by_user_id = auth.uid() AND EXISTS (
      SELECT 1 FROM mp_participants p
      WHERE p.session_id = mp_queue.session_id
        AND p.user_id = auth.uid() AND p.left_at IS NULL
    )
  );

CREATE POLICY mp_queue_dj_or_owner_modify ON mp_queue
  FOR UPDATE
  USING (
    added_by_user_id = auth.uid() OR EXISTS (
      SELECT 1 FROM mp_sessions s
      WHERE s.id = mp_queue.session_id AND s.dj_user_id = auth.uid()
    )
  );

CREATE POLICY mp_vibes_self ON mp_vibes
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY spotify_tokens_self ON spotify_tokens
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

## Redis Keys (Upstash)

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `mp:s:{id}:state` | hash | 12 h | dj_id, track_uri, position_ms, playing, wall_ms, seq |
| `mp:s:{id}:queue` | sorted set | 12 h | queue_item_id ordered by `position` |
| `mp:s:{id}:listeners` | set | 12 h | active user_ids |
| `mp:s:{id}:dj` | string | 12 h | active DJ user_id |
| `mp:s:{id}:rotation_lock` | string | 5 s | mutex for rotation logic |
| `mp:s:{id}:skip:{track_uri}` | string (counter) | 30 m | skip-vote count |
| `mp:s:{id}:skip:{track_uri}:voters` | set | 30 m | who voted (dedupe) |
| `mp:room:{room_id}:sessions` | set | 12 h | active session ids per room |
| `mp:rate:user:{user_id}:queue_adds` | counter | 60 s | 30 adds/min |
| `mp:spotify:rl:{user_id}` | counter | 60 s | local rate limit shadow |

## Appwrite Storage
Bucket: `mp-cache` (album-art proxy)
- Optional CDN for Spotify album-art URLs to reduce client bandwidth abroad.
- File size cap: 1 MB per image.
- TTL: 30 d, regenerated on miss.

## Centrifugo Channels
- `room:{room_id}:mp` — session lifecycle.
- `mp:{session_id}:queue` — queue updates fanout for non-LK clients.
- `user:{user_id}:mp` — private (you-are-dj, premium-required, vote-modal).

## Spotify Token Encryption
- libsodium `crypto_secretbox` with per-user nonce.
- Master key from env `SPOTIFY_TOKEN_KEY` (32 bytes, base64).
- Rotation handled by re-encrypting on next refresh.
