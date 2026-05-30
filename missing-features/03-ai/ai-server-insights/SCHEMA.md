# AI Server Insights — SCHEMA

```sql
CREATE TABLE insights_reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id    UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end   DATE NOT NULL,
  facts        JSONB NOT NULL,
  patterns     JSONB NOT NULL,
  summary_md   TEXT NOT NULL,
  suggestions  JSONB DEFAULT '[]',
  message_id   UUID,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, period_start)
);
CREATE INDEX idx_ir_server_recent ON insights_reports(server_id, period_start DESC);

CREATE TABLE insights_aggregates (
  server_id    UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  bucket       DATE NOT NULL,
  metric       TEXT NOT NULL,
  value        NUMERIC,
  metadata     JSONB DEFAULT '{}',
  PRIMARY KEY (server_id, bucket, metric)
);

CREATE TABLE insights_subscriptions (
  user_id     UUID NOT NULL REFERENCES users(id),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channels    TEXT[] NOT NULL DEFAULT ARRAY['in_app'],
  PRIMARY KEY (user_id, server_id)
);
```

## RLS
```sql
ALTER TABLE insights_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY ir_admin ON insights_reports FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id=auth.uid() AND has_perm('MANAGE_SERVER')));
ALTER TABLE insights_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY isubs_self ON insights_subscriptions FOR ALL
  USING (user_id=auth.uid()) WITH CHECK (user_id=auth.uid());
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `insights:latest:<server>` | report JSON | 24h |

## Migration: `supabase/migrations/134_ai_server_insights.up.sql`

## Aggregator queries (sample)
```sql
-- active members in last 7 days
SELECT count(DISTINCT user_id) FROM messages
WHERE server_id = $1 AND created_at >= now() - interval '7 days';

-- dead channels (no msg in 60d)
SELECT id, name FROM channels c
WHERE c.server_id = $1
  AND NOT EXISTS (SELECT 1 FROM messages m WHERE m.channel_id = c.id AND m.created_at >= now() - interval '60 days');
```
