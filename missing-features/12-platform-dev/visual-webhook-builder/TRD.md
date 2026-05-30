# TRD: Visual Webhook Builder

## Architecture
The webhook builder consists of three pieces: the canvas UI in the Flutter web admin shell, the Go backend that executes pipelines, and a Postgres-backed persistence layer holding templates, runs, and signatures. Inbound webhooks land at `/api/v1/webhooks/in/{webhook_id}` and outbound webhooks are dispatched by a worker pool reading from the same `webhook_runs` table.

## Data Flow
Inbound: HTTP request hits the public endpoint, signature middleware verifies `X-Flicko-Signature` against the stored secret, the handler enqueues a `webhook_runs` row in `pending` state, returns 202, and a worker picks it up and executes the pipeline asynchronously.

Outbound: a Flicko event (message posted, member joined, etc.) is published to the existing event bus. A subscriber filters for events matching active outbound webhooks, enqueues a run, and the worker dispatches an HTTP call with HMAC-signed body.

## Canvas Engine
The frontend canvas uses a state graph (nodes + edges) serialized to JSON. Each node has a typed input/output schema. Saving the canvas posts the graph to `POST /api/v1/webhooks/{id}/graph`, which validates topology (single trigger, no cycles, all destinations reachable), type-checks edge connections, and persists.

Transform nodes use JSONata for expression-driven mappings and Liquid for templated string output. Both run in sandboxed evaluators with hard timeouts: 200 ms for JSONata, 500 ms for Liquid.

## Signing and Verification
Outbound: each webhook stores a 32-byte secret. The dispatcher computes `HMAC-SHA256(secret, timestamp + "." + body)` and emits `X-Flicko-Signature: t={ts},v1={hex}` plus `X-Flicko-Timestamp`. Receivers reject if `now - ts > 5 minutes` to prevent replay.

Inbound: each webhook source stores a verification secret. Middleware computes the same HMAC over the incoming body and rejects mismatches. For sources with their own scheme (GitHub's `X-Hub-Signature-256`, Stripe's `Stripe-Signature`), we ship verifier adapters per template.

Secrets are encrypted at rest with the existing `pgsodium` setup and only decrypted in memory at dispatch time.

## Replay Queue
Failed runs (HTTP 5xx, network error, timeout) move to status `failed_retryable` with `next_retry_at` computed via exponential backoff (1m, 5m, 30m, 2h, 8h, 24h, then dead-letter). A worker scans for runs where `next_retry_at <= now()` and re-dispatches. Bulk replay is implemented as a server-side procedure that resets the retry schedule for matching rows.

## Template System
Templates are versioned JSON documents stored in `webhook_templates`. Each template includes a default graph, an icon, a category, and per-node defaults. Installing a template clones the graph into a new webhook owned by the user. Template version updates are surfaced as in-app banners; users opt in to upgrade.

## API Surface
- `POST /api/v1/webhooks` create a webhook (inbound or outbound).
- `GET /api/v1/webhooks?server_id=...` list.
- `GET /api/v1/webhooks/{id}` fetch detail including graph.
- `POST /api/v1/webhooks/{id}/graph` save graph.
- `POST /api/v1/webhooks/{id}/test` run a test payload through the pipeline.
- `GET /api/v1/webhooks/{id}/runs` paginated history.
- `POST /api/v1/webhooks/{id}/runs/{run_id}/replay` replay one run.
- `POST /api/v1/webhooks/{id}/runs/replay-failed` bulk replay.
- `POST /api/v1/webhooks/{id}/rotate-secret` regenerate the signing secret.
- `POST /api/v1/webhooks/in/{id}` public inbound endpoint.

## Rate Limits and Safety
Inbound endpoints accept up to 60 requests per minute per webhook id with burst of 10. Outbound dispatchers cap at 10 concurrent calls per webhook to prevent overwhelming a destination. Bodies are capped at 1 MB inbound and 256 KB outbound.

## Observability
Every run emits a structured log with `webhook_id`, `run_id`, `status`, `latency_ms`, `attempt`. Prometheus metrics: `webhook_runs_total{status}`, `webhook_dispatch_latency_seconds`, `webhook_retry_queue_depth`. A per-webhook dashboard in the UI shows last 24 hours of success/failure ratio.

## Security
- Secrets are encrypted at rest, masked in UI, never logged.
- The public inbound endpoint is rate-limited per IP and per webhook id.
- Outbound destinations are validated against an SSRF blocklist (no RFC1918, no link-local, no metadata endpoints).
- Replay actions are audit-logged with actor, time, and run id.

## Deployment
Migration 247 introduces `webhook_templates`, `webhook_runs`, `webhook_signatures`, and supporting tables. Feature flag `webhook_builder_enabled` gates the UI and API. Templates are seeded via a seed migration; updates ship as data migrations.

## Failure Modes
- Destination 5xx: retried with backoff up to 6 attempts then dead-lettered.
- Destination 4xx: marked `failed_permanent` immediately; user must edit the webhook.
- Pipeline timeout: run marked `failed_timeout`; not retried; surfaced in UI.
- Signature mismatch on inbound: 401 returned, no run created, counter incremented.
