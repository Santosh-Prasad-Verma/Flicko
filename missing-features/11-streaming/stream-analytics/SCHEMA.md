# Stream Analytics — SCHEMA

```sql
CREATE TABLE stream_metrics (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id   UUID NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
  event_type  TEXT NOT NULL CHECK (event_type IN ('join','leave','heartbeat','chat','reaction','donation')),
  user_id     UUID,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata    JSONB DEFAULT '{}'
);
CREATE INDEX idx_sm_stream_time ON stream_metrics(stream_id, occurred_at);
CREATE INDEX idx_sm_event       ON stream_metrics(event_type, occurred_at);
-- partition by week using pg_partman to keep table small.

CREATE MATERIALIZED VIEW stream_summary_mv AS
SELECT
  stream_id,
  count(DISTINCT user_id) FILTER (WHERE event_type='join') AS unique_viewers,
  count(*) FILTER (WHERE event_type='chat') AS chat_messages,
  EXTRACT(EPOCH FROM max(occurred_at) - min(occurred_at))::INT AS duration_sec,
  jsonb_agg(jsonb_build_object('t', date_trunc('minute', occurred_at), 'event', event_type)) AS timeline
FROM stream_metrics
GROUP BY stream_id;
CREATE UNIQUE INDEX idx_ssm_stream ON stream_summary_mv(stream_id);

CREATE TABLE stream_metric_aggregates (
  stream_id     UUID PRIMARY KEY REFERENCES streams(id) ON DELETE CASCADE,
  peak_viewers  INT,
  unique_viewers INT,
  total_watch_sec BIGINT,
  avg_watch_sec INT,
  chat_per_min  NUMERIC(8,2),
  donations_cents BIGINT DEFAULT 0,
  refreshed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## RLS
```sql
ALTER TABLE stream_metric_aggregates ENABLE ROW LEVEL SECURITY;
CREATE POLICY sma_owner ON stream_metric_aggregates FOR SELECT
  USING (stream_id IN (SELECT id FROM streams WHERE owner_user_id = auth.uid()));
```

## Refresh
```sql
CREATE FUNCTION refresh_stream_aggregates() RETURNS void LANGUAGE sql AS $$
  INSERT INTO stream_metric_aggregates (stream_id, peak_viewers, unique_viewers, ...)
  SELECT ... FROM stream_metrics ... GROUP BY stream_id
  ON CONFLICT (stream_id) DO UPDATE SET ... ;
$$;
SELECT cron.schedule('refresh_stream_aggregates','*/5 * * * *','SELECT refresh_stream_aggregates();');
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `stream:viewers:<id>` | sorted-set | sliding 60s |
| `stream:peak:<id>` | int | live |

## Retention
- Raw events 30 days.
- Aggregates kept indefinitely.

## Migration: `supabase/migrations/234_stream_analytics.up.sql`
