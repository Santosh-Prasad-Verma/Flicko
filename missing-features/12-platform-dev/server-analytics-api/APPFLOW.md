# APPFLOW: Server Analytics API

## Flow 1: Generating an API Token
1. Server owner navigates to Server Settings → Integrations → Analytics API.
2. Frontend calls `GET /api/v1/analytics/tokens?server_id=...` to render the existing list.
3. User clicks Generate Token, fills in name, role, tier, and submits.
4. Frontend calls `POST /api/v1/analytics/tokens` with `{name, role, tier, server_id}`.
5. Backend generates a cryptographically random 32-byte secret, prefixes it with `flk_an_`, computes the SHA-256 digest with a per-row salt, inserts into `analytics_api_tokens`, and returns the plaintext value exactly once.
6. Frontend renders the reveal pill; user copies the token.
7. Background: an audit log row is written with actor, server, action `token.created`.

## Flow 2: Reading a Metric
1. External client sends `GET /api/v1/analytics/servers/123/messages/timeseries?granularity=day&from=2026-04-01&to=2026-04-30` with `Authorization: Bearer flk_an_...`.
2. Auth middleware extracts the bearer, hashes it, looks up the token row, attaches the token context to the request.
3. Authorization middleware verifies `token.server_id == path.server_id`. Mismatch yields 403.
4. Rate-limit middleware decrements the bucket via Redis Lua. If exceeded, returns 429 with `Retry-After`.
5. Handler validates query params (granularity in allowed set, range under 365 days, `from < to`).
6. Service queries `analytics_metrics_mv` filtered by server, metric, bucket range. Returns a slice of `{bucket, value}`.
7. If the requested window includes the trailing 30 minutes (past the view watermark), service merges live results from the raw table.
8. Response is serialized as JSON and streamed. Headers include rate-limit info, request ID, and a `Cache-Control: max-age=60` so well-behaved clients can cache.
9. Async log emission with latency and cache hit status.

## Flow 3: Async Export
1. Client calls `POST /api/v1/analytics/exports` with `{server_id, metric, format, granularity, from, to}`.
2. Auth and rate-limit middleware run as above; export creation has its own bucket.
3. Service inserts a row into `analytics_export_jobs` with `status='queued'`, returns `{job_id}`.
4. Worker pool picks the job using `SELECT ... FOR UPDATE SKIP LOCKED`, transitions to `running`.
5. Worker executes the underlying query in a streaming cursor and writes gzipped CSV chunks to a temp file.
6. On completion, worker uploads to Supabase storage at `analytics-exports/{server_id}/{job_id}.csv.gz`, transitions row to `ready` with `storage_path` and `row_count`.
7. Client polls `GET /exports/{job_id}` every 2-5 seconds; receives `status` and progress percent.
8. Once `ready`, client calls `GET /exports/{job_id}/download`. Service generates a 15-minute signed URL via Supabase storage and returns it.
9. Client downloads the file directly from Supabase storage.

## Flow 4: Token Rotation
1. User clicks Rotate on a token row.
2. Backend creates a new secret, hashes it, inserts a new row pointing to the same logical token slot, and marks the old row `rotated_at = now()`.
3. The old hash continues to authenticate for 24 hours, after which it is rejected.
4. Frontend reveals the new value once.
5. Audit log records `token.rotated`.

## Flow 5: Materialized View Refresh
1. Cron worker fires every 30 minutes.
2. For each metric, it issues `REFRESH MATERIALIZED VIEW CONCURRENTLY analytics_metrics_mv_<metric>`.
3. Refresh duration and row count are recorded in `analytics_view_refresh_log`.
4. If a refresh exceeds 10 minutes, an alert is raised and the next refresh is skipped to prevent overlap.
5. Health endpoint `/internal/analytics/health` reports the freshness watermark consumed by both the API (for stale fallbacks) and the dashboard banner.

## Flow 6: Rate Limit Exceeded
1. Client exceeds 600 req/min on a Pro tier token.
2. Middleware returns 429 with `Retry-After: 23` and `X-RateLimit-Remaining: 0`.
3. Response body includes `{error: "rate_limited", reset_at: "2026-04-22T18:30:00Z"}`.
4. Frontend SDKs surface this as a typed `RateLimitError` so callers can wait and retry deterministically.

## Flow 7: Stale View Degraded Mode
1. Refresh worker fails for 6 consecutive cycles.
2. Health endpoint flips watermark to `stale`.
3. API responses include `X-Data-Stale: true` and a JSON warning field.
4. Dashboard surfaces a yellow banner with the last successful refresh timestamp.
5. On-call is paged via the existing alerting integration.
