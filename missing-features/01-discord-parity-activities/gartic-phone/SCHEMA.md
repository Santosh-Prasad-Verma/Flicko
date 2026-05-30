# Gartic Phone — Schema

## 1. Tables

```sql
CREATE TABLE gp_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  host_user_id    UUID NOT NULL REFERENCES users(id),
  phase           TEXT NOT NULL DEFAULT 'lobby'
                    CHECK (phase IN ('lobby','prompt','draw','caption','reveal','results','archived')),
  round           INT  NOT NULL DEFAULT 0,
  total_rounds    INT  NOT NULL DEFAULT 0,
  prompt_seconds  INT  NOT NULL DEFAULT 30,
  draw_seconds    INT  NOT NULL DEFAULT 60,
  caption_seconds INT  NOT NULL DEFAULT 30,
  mode            TEXT NOT NULL DEFAULT 'normal'
                    CHECK (mode IN ('normal','knock_off','secret')),
  deadline_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at        TIMESTAMPTZ
);
CREATE INDEX idx_gp_sessions_channel ON gp_sessions(channel_id);
CREATE INDEX idx_gp_sessions_active  ON gp_sessions(deadline_at) WHERE phase NOT IN ('archived','results');

CREATE TABLE gp_participants (
  session_id UUID NOT NULL REFERENCES gp_sessions(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id),
  seat       INT  NOT NULL,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at    TIMESTAMPTZ,
  PRIMARY KEY (session_id, user_id),
  UNIQUE (session_id, seat)
);

CREATE TABLE gp_prompts (
  session_id UUID NOT NULL REFERENCES gp_sessions(id) ON DELETE CASCADE,
  chain_id   INT  NOT NULL,
  user_id    UUID NOT NULL REFERENCES users(id),
  text       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, chain_id)
);

CREATE TABLE gp_drawings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  UUID NOT NULL REFERENCES gp_sessions(id) ON DELETE CASCADE,
  chain_id    INT  NOT NULL,
  round       INT  NOT NULL,
  user_id     UUID NOT NULL REFERENCES users(id),
  blob_url    TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (session_id, chain_id, round)
);

CREATE TABLE gp_captions (
  session_id UUID NOT NULL REFERENCES gp_sessions(id) ON DELETE CASCADE,
  chain_id   INT  NOT NULL,
  round      INT  NOT NULL,
  user_id    UUID NOT NULL REFERENCES users(id),
  text       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, chain_id, round)
);
```

## 2. RLS

```sql
ALTER TABLE gp_sessions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE gp_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE gp_prompts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE gp_drawings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE gp_captions    ENABLE ROW LEVEL SECURITY;

CREATE POLICY gp_sessions_read ON gp_sessions FOR SELECT
  USING (channel_id IN (SELECT channel_id FROM channel_members WHERE user_id = auth.uid()));

CREATE POLICY gp_sessions_write ON gp_sessions FOR INSERT
  WITH CHECK (host_user_id = auth.uid());

CREATE POLICY gp_participants_self ON gp_participants FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Prompts/drawings/captions: read if session readable; write if you own the row
CREATE POLICY gp_artifact_read ON gp_drawings FOR SELECT
  USING (session_id IN (SELECT id FROM gp_sessions));
CREATE POLICY gp_artifact_write ON gp_drawings FOR INSERT
  WITH CHECK (user_id = auth.uid());
-- (Mirror for gp_prompts, gp_captions.)
```

## 3. Triggers

```sql
CREATE TRIGGER trg_gp_sessions_phase_advance
  AFTER UPDATE OF phase ON gp_sessions
  FOR EACH ROW EXECUTE FUNCTION pg_notify('gp_phase_advance', NEW.id::text);
```

## 4. Migration
- Up: `supabase/migrations/123_gartic_phone.up.sql`
- Down: drops above tables (cascade).

## 5. Cache (Redis)
| Key | Value | TTL |
|-----|-------|-----|
| `gp:session:<id>` | JSON state cache | 30 s |
| `gp:lock:<id>` | lock for advance worker | 5 s |

## 6. Object Storage (Appwrite)
- Bucket `gartic-drawings`
- Allowed MIME: `image/png`, `image/webp`
- Max: 512 KB per drawing
- Permissions: read=session participants, write=author

## 7. Retention
- Drawings/captions purged 30 days after session end (pg_cron daily sweep).
- GIF exports stored 90 days.

## 8. Sample
```sql
SELECT s.id, count(p.user_id) AS players
FROM gp_sessions s LEFT JOIN gp_participants p USING (session_id)
WHERE s.channel_id = $1 AND s.phase != 'archived'
GROUP BY s.id ORDER BY s.created_at DESC LIMIT 10;
```
