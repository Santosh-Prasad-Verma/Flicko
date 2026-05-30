# Reward System — Schema

## Tables

```sql
CREATE TABLE reward_rules (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  trigger     TEXT NOT NULL CHECK (trigger IN ('messages_count','voice_minutes','daily_streak','reaction_count','event_attended','custom')),
  threshold   INT  NOT NULL,
  window      TEXT NOT NULL DEFAULT 'lifetime' CHECK (window IN ('day','week','month','lifetime')),
  reward_kind TEXT NOT NULL CHECK (reward_kind IN ('coins','role','badge','item','xp')),
  reward_ref  TEXT NOT NULL,
  reward_amt  INT  NOT NULL DEFAULT 0,
  enabled     BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reward_rules_server ON reward_rules(server_id) WHERE enabled;

CREATE TABLE reward_grants (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id       UUID NOT NULL REFERENCES reward_rules(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id),
  server_id     UUID NOT NULL REFERENCES servers(id),
  granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  metric_value  INT  NOT NULL,
  ledger_ref    UUID,
  UNIQUE (rule_id, user_id, granted_at::date)
);
CREATE INDEX idx_reward_grants_user ON reward_grants(user_id, server_id, granted_at);

CREATE TABLE reward_metrics (
  user_id    UUID NOT NULL REFERENCES users(id),
  server_id  UUID NOT NULL REFERENCES servers(id),
  trigger    TEXT NOT NULL,
  bucket     DATE NOT NULL,
  value      INT  NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, server_id, trigger, bucket)
);
```

## RLS
```sql
ALTER TABLE reward_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY rr_read ON reward_rules FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));
CREATE POLICY rr_write ON reward_rules FOR ALL
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND has_perm('MANAGE_REWARDS')));

ALTER TABLE reward_grants ENABLE ROW LEVEL SECURITY;
CREATE POLICY rg_read_self ON reward_grants FOR SELECT USING (user_id = auth.uid());
CREATE POLICY rg_read_mod  ON reward_grants FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid() AND has_perm('MANAGE_REWARDS')));
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `rwd:rules:<server_id>` | rules JSON | 5m |
| `rwd:metric:<user_id>:<server_id>:<trigger>:<bucket>` | counter | until grant |

## Migrations: `supabase/migrations/179_reward_system.up.sql`

## Worker
- `reward_evaluator` worker subscribes NATS `flicko.activity.*` and increments `reward_metrics` atomically. On threshold cross, inserts `reward_grants` and dispatches reward via wallet/role/badge service.
- pg_cron daily sweep recomputes rolling-window thresholds.
