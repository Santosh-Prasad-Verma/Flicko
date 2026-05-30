# Regional Voice Servers — Backend Schema

## 1. Tables

### `voice_regions`

Catalog of deployed LiveKit regions with health + load.

```sql
CREATE TABLE voice_regions (
  code              TEXT PRIMARY KEY,                 -- 'na-east', 'eu-west'
  display_name      TEXT NOT NULL,
  ws_url            TEXT NOT NULL,                    -- 'wss://na-east.voice.flicko.app'
  api_url           TEXT NOT NULL,                    -- internal LiveKit API
  health_url        TEXT NOT NULL,                    -- 'https://na-east.voice.flicko.app/health'
  enabled           BOOLEAN NOT NULL DEFAULT false,
  draining          BOOLEAN NOT NULL DEFAULT false,
  healthy           BOOLEAN NOT NULL DEFAULT true,
  load_pct          NUMERIC(5,2) NOT NULL DEFAULT 0,
  last_health_check TIMESTAMPTZ,
  data_residency    TEXT,                             -- 'EU' / 'US' / 'KR' / null
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_voice_regions_enabled ON voice_regions(enabled, healthy, draining);
```

### `voice_sessions`

Live + completed sessions; basis for analytics.

```sql
CREATE TABLE voice_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  region_code     TEXT NOT NULL REFERENCES voice_regions(code),
  joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at         TIMESTAMPTZ,
  reason_left     TEXT,                               -- 'normal' | 'failover' | 'kicked' | 'error'
  rtc_token_iss   TIMESTAMPTZ NOT NULL DEFAULT now(),
  rtc_token_exp   TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_voice_sessions_channel ON voice_sessions(channel_id, joined_at DESC);
CREATE INDEX idx_voice_sessions_user    ON voice_sessions(user_id, joined_at DESC);
CREATE INDEX idx_voice_sessions_region  ON voice_sessions(region_code, joined_at DESC);
CREATE INDEX idx_voice_sessions_active  ON voice_sessions(channel_id) WHERE left_at IS NULL;
```

### `voice_session_metrics`

Per-session quality metrics.

```sql
CREATE TABLE voice_session_metrics (
  session_id      UUID PRIMARY KEY REFERENCES voice_sessions(id) ON DELETE CASCADE,
  rtt_p50_ms      INT,
  rtt_p99_ms      INT,
  jitter_ms       INT,
  loss_pct        NUMERIC(5,2),
  mos             NUMERIC(3,2),                       -- mean opinion score 1.0–5.0
  participants_n  INT,
  duration_secs   INT,
  recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `voice_region_failovers`

Audit log of failover events.

```sql
CREATE TABLE voice_region_failovers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  UUID NOT NULL REFERENCES voice_sessions(id) ON DELETE CASCADE,
  from_region TEXT NOT NULL,
  to_region   TEXT NOT NULL,
  trigger     TEXT NOT NULL,                          -- 'rtt_high' | 'loss_high' | 'manual' | 'region_drain'
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_voice_failovers_session ON voice_region_failovers(session_id);
```

### `profiles` (column add)

```sql
ALTER TABLE profiles
  ADD COLUMN pinned_voice_region TEXT REFERENCES voice_regions(code);
```

### `servers` (column add)

```sql
ALTER TABLE servers
  ADD COLUMN pinned_voice_region TEXT REFERENCES voice_regions(code),
  ADD COLUMN allowed_voice_regions TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
```

## 2. RLS Policies

```sql
ALTER TABLE voice_regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_session_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_region_failovers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public reads enabled regions"
  ON voice_regions FOR SELECT USING (enabled = true);

CREATE POLICY "Admins write regions"
  ON voice_regions FOR ALL
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "User reads own sessions"
  ON voice_sessions FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Service role writes sessions"
  ON voice_sessions FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Service role manages metrics"
  ON voice_session_metrics FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "User reads own failovers"
  ON voice_region_failovers FOR SELECT
  USING (EXISTS (SELECT 1 FROM voice_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));

CREATE POLICY "Service role writes failovers"
  ON voice_region_failovers FOR INSERT
  WITH CHECK (auth.role() = 'service_role');
```

## 3. Triggers

```sql
CREATE TRIGGER voice_regions_set_updated_at
  BEFORE UPDATE ON voice_regions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- pg_notify when a region's health changes (so backend caches refresh)
CREATE OR REPLACE FUNCTION voice_region_notify_health() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.healthy IS DISTINCT FROM OLD.healthy
     OR NEW.draining IS DISTINCT FROM OLD.draining
     OR NEW.enabled IS DISTINCT FROM OLD.enabled THEN
    PERFORM pg_notify('voice_region_health_changed', NEW.code);
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER voice_regions_health_notify
  AFTER UPDATE ON voice_regions
  FOR EACH ROW EXECUTE FUNCTION voice_region_notify_health();
```

## 4. Migration File

Path: `supabase/migrations/263_regional_voice_servers.up.sql`
Down: `supabase/migrations/263_regional_voice_servers.down.sql`

```sql
-- up
BEGIN;

CREATE TABLE voice_regions (...);
CREATE TABLE voice_sessions (...);
CREATE TABLE voice_session_metrics (...);
CREATE TABLE voice_region_failovers (...);

ALTER TABLE profiles ADD COLUMN pinned_voice_region TEXT REFERENCES voice_regions(code);
ALTER TABLE servers
  ADD COLUMN pinned_voice_region TEXT REFERENCES voice_regions(code),
  ADD COLUMN allowed_voice_regions TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

CREATE FUNCTION voice_region_notify_health() ...;
CREATE TRIGGER voice_regions_health_notify ...;

INSERT INTO voice_regions(code, display_name, ws_url, api_url, health_url, enabled, data_residency) VALUES
  ('na-east','NA East','wss://na-east.voice.flicko.app',
    'https://na-east.voice.flicko.app','https://na-east.voice.flicko.app/health', true, 'US'),
  ('na-west','NA West','wss://na-west.voice.flicko.app',
    'https://na-west.voice.flicko.app','https://na-west.voice.flicko.app/health', false, 'US'),
  ('eu-west','EU West','wss://eu-west.voice.flicko.app',
    'https://eu-west.voice.flicko.app','https://eu-west.voice.flicko.app/health', false, 'EU'),
  ('ap-southeast','APAC SE','wss://ap-southeast.voice.flicko.app',
    'https://ap-southeast.voice.flicko.app','https://ap-southeast.voice.flicko.app/health', false, 'JP'),
  ('ap-south','APAC S','wss://ap-south.voice.flicko.app',
    'https://ap-south.voice.flicko.app','https://ap-south.voice.flicko.app/health', false, 'IN'),
  ('sa-east','SA East','wss://sa-east.voice.flicko.app',
    'https://sa-east.voice.flicko.app','https://sa-east.voice.flicko.app/health', false, 'BR');

COMMIT;
```

```sql
-- down
BEGIN;
DROP TRIGGER IF EXISTS voice_regions_health_notify ON voice_regions;
DROP FUNCTION IF EXISTS voice_region_notify_health();
ALTER TABLE servers
  DROP COLUMN IF EXISTS allowed_voice_regions,
  DROP COLUMN IF EXISTS pinned_voice_region;
ALTER TABLE profiles DROP COLUMN IF EXISTS pinned_voice_region;
DROP TABLE IF EXISTS voice_region_failovers;
DROP TABLE IF EXISTS voice_session_metrics;
DROP TABLE IF EXISTS voice_sessions;
DROP TABLE IF EXISTS voice_regions;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `voice:regions:enabled` | JSON list | 30s |
| `voice:region:<code>:health` | JSON object | 30s |
| `voice:session:<id>` | JSON | duration of session |
| `voice:user:<id>:pinned` | region code | 10m |

## 6. Search Index

Not used.

## 7. Vector Index

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- `voice_sessions`: 90d hot, archive monthly to R2.
- `voice_session_metrics`: 365d (analytics value).
- `voice_region_failovers`: 90d hot, archive.
- `voice_regions`: never drop; `enabled=false` to retire.

## 10. Sample Queries

```sql
-- All healthy regions
SELECT code, ws_url, load_pct
FROM voice_regions
WHERE enabled = true AND healthy = true AND draining = false
ORDER BY load_pct;

-- Currently active sessions per region
SELECT region_code, COUNT(*) AS active
FROM voice_sessions
WHERE left_at IS NULL
GROUP BY region_code
ORDER BY active DESC;

-- p50/p99 quality per region last 24h
SELECT s.region_code,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY m.rtt_p50_ms) AS p50_rtt,
       PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY m.rtt_p99_ms) AS p99_rtt,
       AVG(m.mos) AS avg_mos
FROM voice_sessions s
JOIN voice_session_metrics m ON m.session_id = s.id
WHERE s.joined_at > now() - INTERVAL '24 hours'
GROUP BY s.region_code
ORDER BY p50_rtt;

-- Recent failovers
SELECT from_region, to_region, trigger, COUNT(*) AS n
FROM voice_region_failovers
WHERE occurred_at > now() - INTERVAL '7 days'
GROUP BY from_region, to_region, trigger
ORDER BY n DESC;
```
