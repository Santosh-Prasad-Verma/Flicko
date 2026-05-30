# AI Emoji Suggester — SCHEMA

Pure client feature.

```sql
ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS emoji_suggester JSONB NOT NULL DEFAULT '{"enabled": true}'::jsonb;
```

Optional analytics (server-side):

```sql
CREATE TABLE emoji_suggestion_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID,
  shown       BOOLEAN NOT NULL,
  accepted    BOOLEAN NOT NULL DEFAULT false,
  emoji       TEXT,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ese_time ON emoji_suggestion_events(occurred_at DESC);
```

Privacy: text not stored, only emoji + user_id (and only if user opts into analytics).

## Migration: `supabase/migrations/135_ai_emoji_suggester.up.sql`

## Cache
None.

## Storage
- App-bundle assets (~600KB): `assets/models/emoji-suggester-300d.bin`, `assets/models/emoji-vectors.json`.
