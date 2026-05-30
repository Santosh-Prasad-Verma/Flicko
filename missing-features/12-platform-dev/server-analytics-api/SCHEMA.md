# SCHEMA: Server Analytics API

## Migration 246: Analytics Foundation

### Table: `analytics_api_tokens`
```sql
CREATE TABLE analytics_api_tokens (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id     UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  token_hash    BYTEA NOT NULL,
  token_salt    BYTEA NOT NULL,
  prefix        TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('read', 'read:exports')),
  tier          TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro', 'enterprise')),
  created_by    UUID NOT NULL REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at  TIMESTAMPTZ,
  rotated_at    TIMESTAMPTZ,
  revoked_at    TIMESTAMPTZ
);
CREATE UNIQUE INDEX analytics_api_tokens_hash_idx ON analytics_api_tokens(token_hash);
CREATE INDEX analytics_api_tokens_server_idx ON analytics_api_tokens(server_id) WHERE revoked_at IS NULL;
```

RLS: server owners and admins can SELECT/INSERT/UPDATE rows where `server_id` matches a server they own. Plain members see nothing.

### Table: `analytics_export_jobs`
```sql
CREATE TABLE analytics_export_jobs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id     UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  token_id      UUID REFERENCES analytics_api_tokens(id) ON DELETE SET NULL,
  requested_by  UUID REFERENCES auth.users(id),
  metric        TEXT NOT NULL,
  format        TEXT NOT NULL CHECK (format IN ('csv', 'json')),
  granularity   TEXT NOT NULL CHECK (granularity IN ('hour', 'day', 'week')),
  range_from    DATE NOT NULL,
  range_to      DATE NOT NULL,
  status        TEXT NOT NULL CHECK (status IN ('queued', 'running', 'ready', 'failed')),
  storage_path  TEXT,
  row_count     BIGINT,
  error_reason  TEXT,
  progress_pct  SMALLINT DEFAULT 0,
  queued_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at    TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days')
);
CREATE INDEX analytics_export_jobs_server_idx ON analytics_export_jobs(server_id, queued_at DESC);
CREATE INDEX analytics_export_jobs_queued_idx ON analytics_export_jobs(status, queued_at) WHERE status IN ('queued', 'running');
```

A nightly cron deletes rows where `expires_at < now()` and removes the corresponding storage object.

### Materialized View: `analytics_metrics_mv`
```sql
CREATE MATERIALIZED VIEW analytics_metrics_mv AS
SELECT
  server_id,
  metric,
  bucket_day,
  SUM(value)::BIGINT AS value
FROM (
  SELECT server_id, 'messages' AS metric, date_trunc('day', created_at)::DATE AS bucket_day, COUNT(*) AS value
    FROM messages
    WHERE created_at > now() - interval '400 days'
    GROUP BY 1, 3
  UNION ALL
  SELECT server_id, 'active_members', date_trunc('day', last_seen_at)::DATE, COUNT(DISTINCT user_id)
    FROM server_member_activity
    WHERE last_seen_at > now() - interval '400 days'
    GROUP BY 1, 3
  UNION ALL
  SELECT server_id, 'voice_minutes', date_trunc('day', joined_at)::DATE, SUM(duration_seconds) / 60
    FROM voice_sessions
    WHERE joined_at > now() - interval '400 days'
    GROUP BY 1, 3
) src
GROUP BY server_id, metric, bucket_day;

CREATE UNIQUE INDEX analytics_metrics_mv_pk ON analytics_metrics_mv(server_id, metric, bucket_day);
CREATE INDEX analytics_metrics_mv_server_metric_idx ON analytics_metrics_mv(server_id, metric, bucket_day DESC);
```

Refreshed concurrently every 30 minutes via `pg_cron`.

### Table: `analytics_view_refresh_log`
```sql
CREATE TABLE analytics_view_refresh_log (
  id           BIGSERIAL PRIMARY KEY,
  metric       TEXT NOT NULL,
  started_at   TIMESTAMPTZ NOT NULL,
  finished_at  TIMESTAMPTZ,
  duration_ms  INTEGER,
  row_count    BIGINT,
  status       TEXT NOT NULL CHECK (status IN ('ok', 'failed', 'timeout'))
);
CREATE INDEX analytics_view_refresh_log_recent_idx ON analytics_view_refresh_log(metric, started_at DESC);
```

### Channel-Level View: `analytics_channel_engagement_mv`
```sql
CREATE MATERIALIZED VIEW analytics_channel_engagement_mv AS
SELECT
  server_id,
  channel_id,
  date_trunc('day', created_at)::DATE AS bucket_day,
  COUNT(*) AS messages,
  COUNT(DISTINCT author_id) AS unique_authors,
  AVG(LENGTH(content))::NUMERIC(10,2) AS avg_message_length
FROM messages
WHERE created_at > now() - interval '180 days'
GROUP BY server_id, channel_id, bucket_day;

CREATE UNIQUE INDEX analytics_channel_engagement_pk
  ON analytics_channel_engagement_mv(server_id, channel_id, bucket_day);
```

### Retention Cohorts: `analytics_member_cohorts_mv`
```sql
CREATE MATERIALIZED VIEW analytics_member_cohorts_mv AS
SELECT
  server_id,
  date_trunc('week', joined_at)::DATE AS cohort_week,
  date_trunc('week', last_seen_at)::DATE AS active_week,
  COUNT(DISTINCT user_id) AS members
FROM server_memberships sm
JOIN server_member_activity sma USING (server_id, user_id)
WHERE joined_at > now() - interval '365 days'
GROUP BY 1, 2, 3;

CREATE UNIQUE INDEX analytics_member_cohorts_pk
  ON analytics_member_cohorts_mv(server_id, cohort_week, active_week);
```

## Indexes and Performance Notes
- All hot lookups go through composite indexes leading with `server_id` so RLS filters are sargable.
- Refresh order is messages, channel engagement, members, voice. Voice is last so a slow voice refresh never blocks the dashboard.
- The unique indexes on each materialized view enable `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

## RLS Policies
```sql
ALTER TABLE analytics_api_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY analytics_tokens_owner_rw ON analytics_api_tokens
  FOR ALL TO authenticated
  USING (server_id IN (SELECT server_id FROM server_admins WHERE user_id = auth.uid()))
  WITH CHECK (server_id IN (SELECT server_id FROM server_admins WHERE user_id = auth.uid()));

ALTER TABLE analytics_export_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY analytics_exports_owner_r ON analytics_export_jobs
  FOR SELECT TO authenticated
  USING (server_id IN (SELECT server_id FROM server_admins WHERE user_id = auth.uid()));
```
