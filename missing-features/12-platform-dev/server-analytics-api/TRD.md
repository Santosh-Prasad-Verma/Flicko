# TRD: Server Analytics API

## Architecture
The Analytics API is a new package inside the existing Go monolith at `backend/internal/analytics/`. It owns three subsystems: the read API, the export pipeline, and the materialized view refresh scheduler. All three share a single Postgres connection pool and a Redis instance for rate-limiting counters.

Read requests hit endpoints under `/api/v1/analytics/...`. Authentication accepts either a Supabase user JWT (for the in-app dashboard) or an API token (for programmatic use). API tokens are validated by hashing the bearer value with SHA-256 and looking up the digest in `analytics_api_tokens`.

## Components
- `analytics/router.go` wires endpoints into the global chi router.
- `analytics/service.go` orchestrates reads against materialized views and falls back to live queries when a view is stale.
- `analytics/exports/` contains the job dispatcher and CSV/JSON writers.
- `analytics/views/` contains migration-driven SQL for materialized views, indexes, and refresh procs.
- `analytics/ratelimit/` wraps a token-bucket implementation backed by Redis `EVAL` scripts.

## Read Path
A request for `/messages/timeseries?granularity=day&from=2026-01-01&to=2026-04-01` resolves to a single SELECT against `analytics_metrics_mv` filtered by `server_id`, `metric='messages'`, and the date range. The view is keyed `(server_id, metric, bucket_day)` so the planner uses an index-only scan. The handler streams JSON via `encoding/json` directly to the response writer.

If the requested window crosses the freshness watermark (anything in the last 30 minutes), the service issues a small live query against the raw `messages` table for the trailing slice and stitches the result.

## Export Path
`POST /exports` validates the request, inserts a row into `analytics_export_jobs` with status `queued`, and returns the job ID. A worker pool (configurable, default 4) polls for queued jobs using `SELECT ... FOR UPDATE SKIP LOCKED`. The worker streams query results into a gzipped CSV uploaded to Supabase storage at `analytics-exports/{server_id}/{job_id}.csv.gz`. On completion the row transitions to `ready` with the storage path.

`GET /exports/{job_id}/download` issues a 15-minute signed URL using Supabase's storage signing API. The URL is never cached; clients must request it each time.

## Rate Limiting
Each token has a tier: `free` (60 req/min, 5 exports/hour), `pro` (600 req/min, 60 exports/hour), `enterprise` (negotiated). The middleware computes the bucket key as `ratelimit:{token_id}:{minute}` and decrements via a Lua script that returns the remaining count atomically. Exceeded buckets respond with 429 and `Retry-After`.

## Materialized View Refresh
A cron entry refreshes `analytics_metrics_mv` every 30 minutes using `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Refresh is sharded by metric so a slow voice metric does not block message refresh. A health check exposes `last_refresh_at` per metric for observability.

## Error Handling
- 400 for invalid date ranges, granularity, or unknown metrics.
- 401 for missing or invalid bearer.
- 403 if the token's `server_id` does not match the path.
- 404 for missing export jobs.
- 429 for rate-limited requests.
- 503 if the materialized view is more than 6 hours stale (degraded mode banner in the UI).

## Observability
Every request emits a structured log line with `server_id`, `token_id`, `endpoint`, `latency_ms`, `cache_hit`. Prometheus exports expose request counts by status, p50/p95/p99 latency, export queue depth, and materialized-view refresh duration.

## Security
- Tokens are stored hashed with a per-row salt; lookup uses the digest.
- Tokens are scoped to a single server; cross-server access is rejected at the middleware layer.
- All export downloads are signed and short-lived; no long-lived links.
- Audit log captures token creation, rotation, revocation, and every export job initiation.

## Deployment
- Migration 246 introduces the analytics tables and materialized views.
- Feature flag `analytics_api_enabled` gates the router. Disabled by default in production until alpha is signed off.
- Worker count is set via `ANALYTICS_EXPORT_WORKERS` env var.

## Testing
- Unit tests cover the rate-limit Lua script, time bucketing, and CSV writer.
- Integration tests run against a Supabase ephemeral project with seeded fixtures for 30 days of synthetic message data.
- A k6 load script asserts p95 under 250 ms at 200 RPS against the read endpoints.
