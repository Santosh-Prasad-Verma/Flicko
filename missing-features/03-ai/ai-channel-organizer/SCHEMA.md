# AI Channel Organizer — SCHEMA

```sql
CREATE TABLE organizer_runs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  triggered_by UUID NOT NULL REFERENCES users(id),
  status      TEXT NOT NULL DEFAULT 'queued'
                CHECK (status IN ('queued','running','completed','failed','canceled')),
  model       TEXT,
  tokens_in   INT,
  tokens_out  INT,
  duration_ms INT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ
);
CREATE INDEX idx_or_server_recent ON organizer_runs(server_id, created_at DESC);

CREATE TABLE org_suggestions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id      UUID NOT NULL REFERENCES organizer_runs(id) ON DELETE CASCADE,
  action      TEXT NOT NULL CHECK (action IN ('archive','rename','merge','move','create_category','split')),
  target_id   UUID,
  payload     JSONB NOT NULL,
  reason      TEXT,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','accepted','dismissed','applied')),
  applied_at  TIMESTAMPTZ
);
CREATE INDEX idx_os_run ON org_suggestions(run_id);
```

## RLS
```sql
ALTER TABLE organizer_runs ENABLE ROW LEVEL SECURITY;
CREATE POLICY or_admin ON organizer_runs FOR ALL
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id=auth.uid() AND has_perm('MANAGE_SERVER')))
  WITH CHECK (triggered_by = auth.uid());
ALTER TABLE org_suggestions ENABLE ROW LEVEL SECURITY;
CREATE POLICY os_read ON org_suggestions FOR SELECT
  USING (run_id IN (SELECT id FROM organizer_runs));
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `organizer:rate:<server>:<day>` | counter | 1d |

## Migration: `supabase/migrations/141_ai_channel_organizer.up.sql`
