# IMPL: Server Analytics API

## Phase 0: Foundations (Week 1)
- Create `backend/internal/analytics/` package skeleton with `router.go`, `service.go`, `auth.go`, `ratelimit.go`, `exports/`, `views/`.
- Land migration 246 introducing `analytics_api_tokens`, `analytics_export_jobs`, `analytics_view_refresh_log`, and the three materialized views.
- Wire `pg_cron` jobs for the 30-minute refresh cycle and the 7-day export cleanup.
- Add the `analytics_api_enabled` feature flag, default off in production.

## Phase 1: Token Lifecycle (Week 2)
- Implement `TokenService.Create`, `Rotate`, `Revoke`, `List`, `Verify`. Hashing uses `crypto/sha256` with a 16-byte random salt; comparison is constant-time.
- Build the auth middleware. It accepts either a Supabase JWT (existing path) or an API token (`Authorization: Bearer flk_an_...`).
- Build the token management endpoints under `/api/v1/analytics/tokens`.
- Frontend: build the Settings → Integrations → Analytics API screen with the create, rotate, revoke flows. Show the token value only once.
- Audit logging hooks for all token mutations.

## Phase 2: Read Endpoints (Week 3-4)
- Implement `GET /api/v1/analytics/servers/{id}/metrics/summary` returning the rolled-up KPIs for the current and previous 30 days.
- Implement `GET /messages/timeseries`, `GET /channels/engagement`, `GET /members/retention-cohorts`.
- Add the live-tail merge logic: when the request range overlaps the last 30 minutes, query the raw table for the trailing window and stitch.
- Add response shaping: pagination via cursor for list endpoints, ISO-8601 timestamps everywhere, tabular `data` array plus `meta` block.
- Wire the in-app dashboard to consume these endpoints. KPIs, timeseries chart, and channel table all share the same client.

## Phase 3: Rate Limiting (Week 4)
- Drop in the Redis-backed token bucket. Lua script handles atomic decrement and TTL on the bucket key.
- Tier definitions live in `analytics/ratelimit/tiers.go` so they are easy to tune.
- Middleware emits headers on every response: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.
- Load test with k6 to confirm bucket math under contention (200 RPS, 50 concurrent tokens).

## Phase 4: Export Pipeline (Week 5-6)
- Implement `POST /exports`, `GET /exports/{job_id}`, `GET /exports/{job_id}/download`.
- Build the worker pool: `analytics/exports/worker.go` polling with `FOR UPDATE SKIP LOCKED`. Configurable concurrency via env var.
- Implement streaming CSV writer that processes the cursor in 5000-row chunks and gzips on the fly.
- Wire Supabase storage upload. Use the official Go client; bucket `analytics-exports` with private ACL.
- Implement signed URL generation (15-minute TTL) on download.
- Frontend: export modal with format/range/granularity, polling job-status panel, retry on failure.

## Phase 5: Observability (Week 6)
- Structured log lines on every request with `server_id`, `token_id`, `endpoint`, `latency_ms`, `cache_hit`, `status`.
- Prometheus metrics: `analytics_request_total{endpoint, status}`, `analytics_request_latency_seconds`, `analytics_export_queue_depth`, `analytics_view_refresh_duration_seconds{metric}`.
- Grafana dashboard with panels for latency, error rate, export throughput, view freshness.
- Alert rules: p95 latency over 500 ms for 10 minutes, view stale over 6 hours, export failure rate above 5 percent.

## Phase 6: Documentation Portal (Week 7)
- Static site at `developers.flicko.app/analytics` built with the existing docs framework.
- Endpoint reference auto-generated from the OpenAPI spec emitted by the Go handlers.
- Code samples in Go, TypeScript (fetch), Python (httpx), and curl.
- Live "Try it" widget backed by a sandbox token bound to a demo server with synthetic data.

## Phase 7: Beta and GA (Week 8-10)
- Closed beta: 20 servers, weekly office hours, dedicated Slack channel for feedback.
- Track beta metrics: token activation rate, endpoint mix, error rate per server.
- GA gate: zero P0/P1 incidents in the final two weeks of beta, p95 within target, feedback synthesized into a v1.1 backlog.
- Public launch post, sample dashboards repo on GitHub, blog post walking through "build a sponsor report in 10 minutes."

## Testing Strategy
- Unit tests in each package, with a 70 percent line-coverage floor.
- Integration tests run a local Supabase via the existing dev harness, seed 30 days of synthetic activity, and exercise every endpoint.
- Contract tests pin response shapes; any field rename is caught in CI.
- Load tests in CI nightly: k6 scenario with 200 RPS sustained, 1000 RPS burst.
- Chaos test: kill the export worker mid-job, assert the job recovers and completes.

## Rollout
- Feature flag in three stages: staff servers, then 50 beta servers, then 100 percent.
- Each stage waits 72 hours with no regression before promoting.
- Kill switch: flipping the flag back disables the router but leaves data untouched.

## Open Items for v1.1
- Voice-channel deep dive (per-channel minute breakdowns).
- Webhook delivery analytics (cross-feature with the webhook builder).
- Scheduled exports (recurring jobs) and email delivery.
- Granular RBAC: read-only API tokens scoped to a single channel.
