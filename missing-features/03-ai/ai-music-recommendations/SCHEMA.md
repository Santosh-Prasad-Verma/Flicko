# AI Music Recommendations — SCHEMA

```sql
CREATE TABLE user_taste_vectors (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  vector      VECTOR(128),
  last_track  TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE music_recs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  context      TEXT NOT NULL CHECK (context IN ('party','dm','digest')),
  context_id   UUID,
  user_id      UUID REFERENCES users(id),
  track_uri    TEXT NOT NULL,
  rationale    TEXT,
  accepted     BOOLEAN,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_mr_context ON music_recs(context, context_id, created_at DESC);

CREATE TABLE music_listening_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id),
  track_uri    TEXT NOT NULL,
  started_at   TIMESTAMPTZ NOT NULL,
  ended_at     TIMESTAMPTZ,
  source       TEXT NOT NULL,
  audio_feats  JSONB
);
CREATE INDEX idx_mle_user_recent ON music_listening_events(user_id, started_at DESC);
```

## RLS
```sql
ALTER TABLE music_listening_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY mle_self ON music_listening_events FOR ALL USING (user_id=auth.uid()) WITH CHECK (user_id=auth.uid());
ALTER TABLE music_recs ENABLE ROW LEVEL SECURITY;
CREATE POLICY mr_self ON music_recs FOR SELECT USING (user_id=auth.uid() OR context_id IN (SELECT id FROM mp_sessions));
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `music:room_vec:<party>` | vector | 5m |
| `music:catalog:<uri>` | track meta | 24h |

## Migration: `supabase/migrations/139_ai_music_recs.up.sql`
