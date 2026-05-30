# Watch Parties — Schema

## Tables

```sql
CREATE TABLE watch_parties (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  host_user_id  UUID NOT NULL REFERENCES users(id),
  url           TEXT NOT NULL,
  provider      TEXT NOT NULL CHECK (provider IN ('youtube','twitch','vimeo','mp4','hls','flicko_vod')),
  external_id   TEXT,
  title         TEXT,
  thumbnail_url TEXT,
  duration_sec  INT,
  state         TEXT NOT NULL DEFAULT 'waiting'
                  CHECK (state IN ('waiting','playing','paused','ended')),
  current_t     NUMERIC(10,3) DEFAULT 0,
  state_ts      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at      TIMESTAMPTZ
);
CREATE INDEX idx_wp_channel ON watch_parties(channel_id) WHERE state != 'ended';
CREATE INDEX idx_wp_active  ON watch_parties(last_seen_at) WHERE state != 'ended';

CREATE TABLE watch_party_participants (
  party_id   UUID NOT NULL REFERENCES watch_parties(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at    TIMESTAMPTZ,
  is_host    BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (party_id, user_id)
);

CREATE TABLE watch_party_providers (
  provider     TEXT PRIMARY KEY,
  oembed_url   TEXT,
  iframe_base  TEXT,
  caps         JSONB NOT NULL DEFAULT '{}'
);
INSERT INTO watch_party_providers VALUES
  ('youtube', 'https://www.youtube.com/oembed', 'https://www.youtube.com/embed/{id}', '{"playback_api":true,"max_quality":"4k"}'),
  ('twitch',  null,                              'https://player.twitch.tv?video={id}', '{"vod_only":true}'),
  ('vimeo',   'https://vimeo.com/api/oembed.json','https://player.vimeo.com/video/{id}', '{}'),
  ('mp4',     null, null, '{"requires_cors":true}'),
  ('hls',     null, null, '{}'),
  ('flicko_vod', null, null, '{}');
```

## RLS
```sql
ALTER TABLE watch_parties ENABLE ROW LEVEL SECURITY;
CREATE POLICY wp_read ON watch_parties FOR SELECT
  USING (channel_id IN (SELECT channel_id FROM channel_members WHERE user_id = auth.uid()));
CREATE POLICY wp_insert ON watch_parties FOR INSERT
  WITH CHECK (host_user_id = auth.uid());
CREATE POLICY wp_update_host ON watch_parties FOR UPDATE
  USING (host_user_id = auth.uid())
  WITH CHECK (host_user_id = auth.uid());
```

## Cache (Redis)
| Key | Value | TTL |
|-----|-------|-----|
| `wp:state:<id>` | JSON {state,t,ts} | live |
| `wp:oembed:<url-hash>` | metadata | 1h |
| `wp:participants:<id>` | set | live |

## Migration: `supabase/migrations/235_watch_parties.up.sql`

## Retention
- Parties pruned 30 days after `ended_at`.
- Participant rows cascaded.
