# Karaoke Night — Schema

## Migration: `122_karaoke.sql`

```sql
-- Migration 122: Karaoke
-- Up

CREATE TABLE IF NOT EXISTS karaoke_sessions (
    id              text PRIMARY KEY,
    room_id         text NOT NULL,
    host_user_id    text NOT NULL,
    state           text NOT NULL DEFAULT 'draft'
                    CHECK (state IN ('draft','ready','cueing','singing','scoring','ended')),
    current_song_id text,
    current_singer_user_id text,
    current_started_at timestamptz,
    rotation_mode   text NOT NULL DEFAULT 'queue'
                    CHECK (rotation_mode IN ('queue','round_robin','free_for_all')),
    settings        jsonb NOT NULL DEFAULT '{
                      "max_listeners": 25,
                      "stealth_default": false,
                      "max_song_seconds": 360
                    }'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    ended_at        timestamptz,
    last_active_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX karaoke_sessions_room_active_idx
  ON karaoke_sessions (room_id)
  WHERE state IN ('ready','cueing','singing','scoring');

CREATE TABLE IF NOT EXISTS karaoke_songs (
    id              text PRIMARY KEY,
    title           text NOT NULL,
    artist          text NOT NULL,
    duration_ms     integer NOT NULL,
    backing_url     text NOT NULL,
    lrc_url         text NOT NULL,
    midi_guide_url  text,
    difficulty      text NOT NULL DEFAULT 'medium'
                    CHECK (difficulty IN ('easy','medium','hard')),
    license         text NOT NULL DEFAULT 'public_domain'
                    CHECK (license IN ('public_domain','cc0','cc_by','user_attested')),
    submitted_by    text,
    review_state    text NOT NULL DEFAULT 'approved'
                    CHECK (review_state IN ('pending','approved','rejected')),
    play_count      integer NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX karaoke_songs_search_idx
  ON karaoke_songs USING gin (to_tsvector('simple', title || ' ' || artist))
  WHERE review_state = 'approved';

CREATE INDEX karaoke_songs_review_idx
  ON karaoke_songs (review_state, created_at);

CREATE TABLE IF NOT EXISTS karaoke_signups (
    id              text PRIMARY KEY,
    session_id      text NOT NULL REFERENCES karaoke_sessions(id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    song_id         text NOT NULL REFERENCES karaoke_songs(id),
    position        double precision NOT NULL,
    state           text NOT NULL DEFAULT 'signed_up'
                    CHECK (state IN ('signed_up','cued','active','completed','abandoned','withdrawn')),
    stealth         boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now(),
    started_at      timestamptz,
    ended_at        timestamptz
);

CREATE INDEX karaoke_signups_session_position_idx
  ON karaoke_signups (session_id, position)
  WHERE state IN ('signed_up','cued');

CREATE INDEX karaoke_signups_user_idx
  ON karaoke_signups (user_id);

CREATE TABLE IF NOT EXISTS karaoke_scores (
    id              bigserial PRIMARY KEY,
    session_id      text NOT NULL REFERENCES karaoke_sessions(id) ON DELETE CASCADE,
    signup_id       text NOT NULL REFERENCES karaoke_signups(id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    song_id         text NOT NULL REFERENCES karaoke_songs(id),
    score           integer,
    pitch_accuracy  numeric(4,3),
    timing          numeric(4,3),
    completeness    numeric(4,3),
    duration_ms     integer,
    stealth         boolean NOT NULL DEFAULT false,
    job_state       text NOT NULL DEFAULT 'pending'
                    CHECK (job_state IN ('pending','running','succeeded','failed','expired')),
    failure_reason  text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    scored_at       timestamptz
);

CREATE INDEX karaoke_scores_user_idx ON karaoke_scores (user_id, created_at DESC);
CREATE INDEX karaoke_scores_session_idx ON karaoke_scores (session_id);
CREATE INDEX karaoke_scores_room_week_idx ON karaoke_scores (session_id, created_at);

CREATE TABLE IF NOT EXISTS karaoke_cheers (
    id              bigserial PRIMARY KEY,
    session_id      text NOT NULL REFERENCES karaoke_sessions(id) ON DELETE CASCADE,
    signup_id       text REFERENCES karaoke_signups(id) ON DELETE CASCADE,
    user_id         text NOT NULL,
    emoji           text NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX karaoke_cheers_signup_idx ON karaoke_cheers (signup_id);

CREATE OR REPLACE FUNCTION karaoke_touch_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER karaoke_sessions_touch
  BEFORE UPDATE ON karaoke_sessions
  FOR EACH ROW EXECUTE FUNCTION karaoke_touch_updated_at();

CREATE TRIGGER karaoke_songs_touch
  BEFORE UPDATE ON karaoke_songs
  FOR EACH ROW EXECUTE FUNCTION karaoke_touch_updated_at();

-- Down
-- DROP TABLE karaoke_cheers;
-- DROP TABLE karaoke_scores;
-- DROP TABLE karaoke_signups;
-- DROP TABLE karaoke_songs;
-- DROP TABLE karaoke_sessions;
-- DROP FUNCTION karaoke_touch_updated_at;
```

## Row Level Security

```sql
ALTER TABLE karaoke_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE karaoke_songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE karaoke_signups ENABLE ROW LEVEL SECURITY;
ALTER TABLE karaoke_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE karaoke_cheers ENABLE ROW LEVEL SECURITY;

-- Sessions: room members read; host writes
CREATE POLICY karaoke_sessions_read ON karaoke_sessions
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM voice_room_members m
            WHERE m.room_id = karaoke_sessions.room_id
              AND m.user_id = auth.uid())
  );

CREATE POLICY karaoke_sessions_host_write ON karaoke_sessions
  FOR UPDATE
  USING (host_user_id = auth.uid())
  WITH CHECK (host_user_id = auth.uid());

CREATE POLICY karaoke_sessions_insert ON karaoke_sessions
  FOR INSERT
  WITH CHECK (host_user_id = auth.uid());

-- Songs: approved are readable to anyone; pending only to submitter or admin
CREATE POLICY karaoke_songs_public ON karaoke_songs
  FOR SELECT
  USING (review_state = 'approved' OR submitted_by = auth.uid());

CREATE POLICY karaoke_songs_submit ON karaoke_songs
  FOR INSERT
  WITH CHECK (submitted_by = auth.uid());

-- Signups
CREATE POLICY karaoke_signups_self ON karaoke_signups
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY karaoke_signups_session_member_read ON karaoke_signups
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM karaoke_sessions s
            JOIN voice_room_members m ON m.room_id = s.room_id
            WHERE s.id = karaoke_signups.session_id
              AND m.user_id = auth.uid())
  );

-- Scores: user reads their own, room members see non-stealth scores
CREATE POLICY karaoke_scores_self ON karaoke_scores
  FOR SELECT
  USING (
    user_id = auth.uid() OR (
      stealth = false AND EXISTS (
        SELECT 1 FROM karaoke_sessions s
        JOIN voice_room_members m ON m.room_id = s.room_id
        WHERE s.id = karaoke_scores.session_id
          AND m.user_id = auth.uid()
      )
    )
  );

-- Cheers
CREATE POLICY karaoke_cheers_self ON karaoke_cheers
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY karaoke_cheers_session_read ON karaoke_cheers
  FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM karaoke_sessions s
            JOIN voice_room_members m ON m.room_id = s.room_id
            WHERE s.id = karaoke_cheers.session_id
              AND m.user_id = auth.uid())
  );
```

## Redis Keys (Upstash)

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `kk:s:{id}:state` | hash | 12 h | song_id, singer, started_at, line_idx |
| `kk:s:{id}:queue` | sorted set | 12 h | signup_ids by `position` |
| `kk:s:{id}:listeners` | set | 12 h | active user_ids |
| `kk:score:jobs` | list | n/a | pitch worker job queue |
| `kk:score:job:{id}` | hash | 1 h | job state, attempts |
| `kk:rate:user:{user_id}:search` | counter | 10 s | search rate limit |
| `kk:rate:user:{user_id}:signup` | counter | 10 s | signup rate limit |

## Appwrite Storage Buckets

`kk-catalog`
- Public-read for approved songs only (signed URLs).
- Stores: `{song_id}/backing.opus`, `{song_id}/lyrics.lrc`, `{song_id}/guide.mid`.

`kk-uploads`
- Private; only worker + admin reads.
- User-submitted backing tracks pending review.

`kk-recordings`
- Private; LiveKit Egress writes mic recordings here.
- Lifecycle: 7 d retention, then auto-delete.
- Permissions: worker read; user can request own recording with signed URL.

## Centrifugo Channels
- `room:{room_id}:kk` — session lifecycle.
- `kk:{session_id}:cues` — fallback when LK data not available.
- `user:{user_id}:kk` — score notifications.
