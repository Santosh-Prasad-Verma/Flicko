# Native RTMP Streaming — Backend Schema

## 1. Tables

### `streams`

Shared with `vod-storage`, `clips-system`, `stream-donations`, `stream-analytics`. Defined here because `native-rtmp-streaming` is the lifecycle owner.

```sql
CREATE TYPE stream_state AS ENUM (
  'pending',     -- ingress created, not publishing yet
  'live',        -- track published, viewers can join
  'paused',      -- stream went black >5s but key still hot
  'ended',       -- stream finished cleanly
  'errored',     -- terminated by webhook with non-clean state
  'revoked'      -- moderator killed it
);

CREATE TYPE stream_protocol AS ENUM ('rtmp', 'rtmps', 'srt', 'whip');

CREATE TABLE streams (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id     UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  azure_acs_room  TEXT NOT NULL,                  -- channel-id mirror
  ingress_id    TEXT,                           -- Azure Media Ingress ID
  state         stream_state NOT NULL DEFAULT 'pending',
  protocol      stream_protocol,
  title         TEXT,
  thumbnail_url TEXT,
  ingest_region TEXT,                           -- eu-west / us-east / asia
  bitrate_kbps  INT,
  width         INT,
  height        INT,
  fps           SMALLINT,
  peak_viewers  INT NOT NULL DEFAULT 0,
  viewer_count  INT NOT NULL DEFAULT 0,
  started_at    TIMESTAMPTZ,
  ended_at      TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT one_live_per_channel
    EXCLUDE (channel_id WITH =) WHERE (state IN ('pending','live','paused'))
);

CREATE INDEX idx_streams_channel_state    ON streams(channel_id, state);
CREATE INDEX idx_streams_server_started   ON streams(server_id, started_at DESC);
CREATE INDEX idx_streams_user             ON streams(user_id, started_at DESC);
```

### `stream_keys`

```sql
CREATE TABLE stream_keys (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  key_prefix    TEXT NOT NULL,                 -- shown in UI
  key_hash      TEXT NOT NULL,                 -- argon2id
  ingest_url    TEXT NOT NULL,
  region        TEXT NOT NULL,
  rotated_at    TIMESTAMPTZ,
  revoked_at    TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT one_active_key_per_channel
    EXCLUDE (channel_id WITH =) WHERE (revoked_at IS NULL)
);

CREATE INDEX idx_stream_keys_user ON stream_keys(user_id);
```

### `stream_events` (audit, append-only)

```sql
CREATE TABLE stream_events (
  id          BIGSERIAL PRIMARY KEY,
  stream_id   UUID NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
  kind        TEXT NOT NULL,                   -- ingress_started, track_published, ...
  payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stream_events_stream_time ON stream_events(stream_id, occurred_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE streams      ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_keys  ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members read public streams"
  ON streams FOR SELECT
  USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );

CREATE POLICY "owner inserts own stream"
  ON streams FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "owner or admin updates"
  ON streams FOR UPDATE
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM server_members sm
            WHERE sm.user_id = auth.uid()
              AND sm.server_id = streams.server_id
              AND sm.is_admin)
  );

CREATE POLICY "owner reads own keys"
  ON stream_keys FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "owner writes own keys"
  ON stream_keys FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER streams_set_updated_at
  BEFORE UPDATE ON streams
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Update peak_viewers automatically
CREATE OR REPLACE FUNCTION bump_peak_viewers() RETURNS trigger AS $$
BEGIN
  IF NEW.viewer_count > NEW.peak_viewers THEN
    NEW.peak_viewers := NEW.viewer_count;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER streams_peak_viewers
  BEFORE UPDATE OF viewer_count ON streams
  FOR EACH ROW EXECUTE FUNCTION bump_peak_viewers();
```

## 4. Migration File

Path: `supabase/migrations/230_native_rtmp_streaming.up.sql`
Down: `supabase/migrations/230_native_rtmp_streaming.down.sql`

```sql
-- 230_native_rtmp_streaming.up.sql
BEGIN;

CREATE TYPE stream_state    AS ENUM ('pending','live','paused','ended','errored','revoked');
CREATE TYPE stream_protocol AS ENUM ('rtmp','rtmps','srt','whip');

-- streams, stream_keys, stream_events tables (see above)

ALTER TABLE streams      ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_keys  ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_events ENABLE ROW LEVEL SECURITY;

-- policies, triggers (see above)

GRANT SELECT, INSERT, UPDATE ON streams      TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON stream_keys TO authenticated;
GRANT SELECT, INSERT ON stream_events  TO authenticated;

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `stream:active:<channel-id>` | stream-id | 60 s |
| `stream:state:<stream-id>` | JSON snapshot | 30 s |
| `stream:viewers:<stream-id>` | sorted set of session-ids, score=last-seen | 90 s sliding |
| `stream:keyhash:<prefix>` | full hash for fast lookup | 1 h |

## 6. Search Index (Meilisearch)

Not indexed during live; the matching VOD row in `vods` is indexed there.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite / R2)

Not applicable in v1 — see `vod-storage` for segment retention.

## 9. Data Retention

- `streams` rows kept 90 d hot; archived to BigQuery monthly for analytics replay.
- `stream_keys` rows kept indefinitely while `revoked_at IS NULL`. Revoked keys soft-purged at 30 d.
- `stream_events` partitioned monthly; rotate after 6 months.

## 10. Sample Queries

```sql
-- live streams in a server, ordered by viewers
SELECT s.id, s.title, s.viewer_count, u.username
FROM streams s
JOIN users u ON u.id = s.user_id
WHERE s.server_id = $1 AND s.state = 'live'
ORDER BY s.viewer_count DESC;

-- stream history for the current user
SELECT id, title, started_at, ended_at, peak_viewers
FROM streams
WHERE user_id = auth.uid()
  AND state IN ('ended','errored','revoked')
ORDER BY started_at DESC
LIMIT 50;

-- detect duplicate publishes against a single key
SELECT key_prefix, COUNT(*) AS active
FROM streams s
JOIN stream_keys k ON k.channel_id = s.channel_id
WHERE s.state IN ('live','pending')
GROUP BY key_prefix
HAVING COUNT(*) > 1;
```
