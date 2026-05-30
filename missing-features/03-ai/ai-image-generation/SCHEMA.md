# AI Image Generation — SCHEMA

```sql
CREATE TABLE image_gens (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id),
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  message_id    UUID,
  prompt        TEXT NOT NULL,
  style         TEXT,
  aspect_ratio  TEXT NOT NULL DEFAULT '1:1',
  provider      TEXT NOT NULL,
  model         TEXT NOT NULL,
  image_url     TEXT,
  status        TEXT NOT NULL DEFAULT 'queued'
                  CHECK (status IN ('queued','generating','moderating','posted','blocked','failed')),
  parent_id     UUID REFERENCES image_gens(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at   TIMESTAMPTZ
);
CREATE INDEX idx_ig_user_recent ON image_gens(user_id, created_at DESC);
CREATE INDEX idx_ig_channel    ON image_gens(channel_id, created_at DESC);

CREATE TABLE image_gen_quotas (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bucket      DATE NOT NULL,
  used        INT NOT NULL DEFAULT 0,
  cap         INT NOT NULL,
  PRIMARY KEY (user_id, bucket)
);

CREATE TABLE image_prompt_filter (
  pattern     TEXT PRIMARY KEY,
  reason      TEXT NOT NULL,
  enabled     BOOLEAN NOT NULL DEFAULT true
);
```

## RLS
```sql
ALTER TABLE image_gens ENABLE ROW LEVEL SECURITY;
CREATE POLICY ig_self_or_member ON image_gens FOR SELECT
  USING (user_id = auth.uid()
      OR channel_id IN (SELECT channel_id FROM channel_members WHERE user_id=auth.uid()));
CREATE POLICY ig_insert_self ON image_gens FOR INSERT
  WITH CHECK (user_id = auth.uid());
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `igen:quota:<user>:<day>` | counter | 1d |
| `igen:rl:provider:pollinations` | token bucket | sliding |

## Migration: `supabase/migrations/136_ai_image_generation.up.sql`

## Storage
- Appwrite bucket `ai-images`. Hot 30d, then archive to R2 or delete.
