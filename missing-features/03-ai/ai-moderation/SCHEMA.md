# AI Moderation — SCHEMA

```sql
CREATE TABLE mod_signals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id    UUID,
  user_id       UUID NOT NULL REFERENCES users(id),
  server_id     UUID REFERENCES servers(id) ON DELETE SET NULL,
  channel_id    UUID REFERENCES channels(id) ON DELETE SET NULL,
  text_hash     TEXT NOT NULL,
  scores        JSONB NOT NULL,
  decision      TEXT NOT NULL CHECK (decision IN ('clean','review','blocked')),
  classifier    TEXT NOT NULL,
  classifier_v  TEXT NOT NULL,
  latency_ms    INT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ms_user_recent ON mod_signals(user_id, created_at DESC);
CREATE INDEX idx_ms_server      ON mod_signals(server_id, created_at DESC);
CREATE INDEX idx_ms_decision    ON mod_signals(decision, created_at DESC);

CREATE TABLE mod_thresholds (
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  category    TEXT NOT NULL,
  block_th    NUMERIC(4,3) NOT NULL,
  review_th   NUMERIC(4,3) NOT NULL,
  PRIMARY KEY (server_id, category)
);

CREATE TABLE mod_queue_items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id   UUID NOT NULL REFERENCES mod_signals(id) ON DELETE CASCADE,
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','approved','denied')),
  decided_by  UUID REFERENCES users(id),
  decided_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE mod_appeals (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_id   UUID NOT NULL REFERENCES mod_signals(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id),
  reason      TEXT,
  status      TEXT NOT NULL DEFAULT 'open',
  decided_by  UUID REFERENCES users(id),
  decided_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## RLS
```sql
ALTER TABLE mod_signals ENABLE ROW LEVEL SECURITY;
CREATE POLICY ms_admin ON mod_signals FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id=auth.uid() AND has_perm('MANAGE_MESSAGES')));
ALTER TABLE mod_appeals ENABLE ROW LEVEL SECURITY;
CREATE POLICY ma_self ON mod_appeals FOR ALL
  USING (user_id=auth.uid()) WITH CHECK (user_id=auth.uid());
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `aimod:safe:<text_hash>` | "1" | 30d (mod-approved) |
| `aimod:user_block_count:<user>` | counter | rolling |

## Migration: `supabase/migrations/137_ai_moderation.up.sql`

## Privacy
- text_hash stored, plaintext NOT stored except in mod_queue while open (purged on resolution).
