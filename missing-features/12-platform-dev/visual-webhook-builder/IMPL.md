# IMPL: Visual Webhook Builder

## Phase 0: Foundations (Week 1-2)
- Create `backend/internal/webhooks/` package with subpackages `engine/`, `dispatcher/`, `signing/`, `templates/`, `replay/`.
- Land migration 247 with `webhooks`, `webhook_templates`, `webhook_runs`, `webhook_signatures`, `webhook_replay_queue`, `webhook_signature_failures`.
- Define the graph schema and validation function in SQL plus Go.
- Stand up the feature flag `webhook_builder_enabled`, default off.
- Wire pgsodium for secret encryption; verify roundtrip in a unit test.

## Phase 1: Graph Engine (Week 3-4)
- Define node interface in Go: `Execute(ctx, input) (output, error)` with a `Validate(config) error` for save-time checks.
- Implement built-in nodes: `trigger.event.message`, `trigger.event.member_joined`, `trigger.http.inbound`, `transform.jsonata`, `transform.liquid`, `destination.channel.post`, `destination.http.outbound`.
- Build the topological executor with hard timeouts: 200 ms for JSONata, 500 ms for Liquid, 10 seconds total pipeline budget.
- Implement the test runner: `Engine.RunDryRun(graph, payload)` that returns per-node outputs without executing destinations.
- Ship unit tests covering each node and full-graph integration tests with 20+ scenarios.

## Phase 2: Inbound Path (Week 4-5)
- Implement `POST /api/v1/webhooks/in/{id}` public handler.
- Implement signature middleware with adapters per scheme: `flicko_v1`, `github`, `stripe`, `custom_hmac`. Constant-time compare via `hmac.Equal`.
- Implement per-IP and per-webhook rate limiting (Redis token bucket reused from analytics work).
- Wire SSRF blocklist for outbound destinations; reject RFC1918, link-local, metadata IPs at validate time and dispatch time.
- Add audit logging for signature mismatches into `webhook_signature_failures`.

## Phase 3: Outbound Path and Dispatcher (Week 5-6)
- Implement event-bus subscriber that enqueues runs for matching outbound webhooks.
- Implement dispatcher worker pool. Workers claim runs with `FOR UPDATE SKIP LOCKED`, dispatch HTTP, record results.
- Implement signing for outbound: `X-Flicko-Signature: t={ts},v1={hex}` and `X-Flicko-Timestamp`.
- Add per-webhook concurrency cap (default 10) to prevent overwhelming destinations.
- Add response body truncation, size caps (1 MB inbound, 256 KB outbound).

## Phase 4: Retry and Replay (Week 6)
- Implement exponential backoff schedule: 1m, 5m, 30m, 2h, 8h, 24h, then dead-letter.
- Implement `POST /runs/{id}/replay` and `POST /runs/replay-failed` endpoints.
- Bulk replay applies jitter over a 60-second window to avoid stampedes.
- Replay drains at a configurable rate (default 10/sec per webhook).
- Add audit logging for replay actions.

## Phase 5: Canvas UI (Week 7-9)
- Build the canvas with a graph rendering library (reuse the Flutter web library used elsewhere, fallback to a custom SVG implementation if performance lags).
- Implement palette, drag-drop, edge drawing, type checking on connection.
- Build node inspector with typed fields, JSONata editor with autocomplete, secret reveal pill.
- Implement save flow: serialize graph, POST, surface validation errors at the right node.
- Build test runner UI: payload editor, sample picker, run button, per-node result panel.

## Phase 6: List, History, Replay UI (Week 9-10)
- Build the webhook list with cards, filters, search, empty states.
- Build the run history tab with pagination, side drawer for full request/response, per-row Replay action.
- Failed-runs banner with bulk Replay All confirmation.
- Wire websocket updates for real-time status changes on the active page.

## Phase 7: Templates and Library (Week 10-11)
- Author the 10 launch templates as JSON documents, each with default graph, icon, signature scheme.
- Build the template browser modal in the New Webhook flow.
- Implement template upgrade banners and the side-by-side diff view.
- Auto-merge logic: preserve user-edited field values when nodes are unchanged; surface conflicts for user resolution.

## Phase 8: Observability and Hardening (Week 11-12)
- Structured logs across the whole pipeline. Prometheus metrics for run counts, latency, retry queue depth, signature failures.
- Per-webhook UI dashboard showing 24h success rate and median latency.
- Pen-test pass focused on signature bypass, SSRF, replay attacks, and timing leaks.
- Load test inbound endpoint at 500 RPS sustained; assert no run loss and acceptable p95.

## Phase 9: Beta and GA (Week 12-14)
- Closed beta with 30 servers; weekly office hours, instrumented feedback collection.
- Watch metrics: template adoption rate, custom-graph creation rate, retry success ratio.
- GA gate: replay success above 95 percent, zero P0/P1 incidents, average time-to-first-webhook under 4 minutes.
- Launch with a guided tour, sample integrations repo, and developer docs at `developers.flicko.app/webhooks`.

## Testing Strategy
- Unit tests per node, including malicious payload fuzzing for JSONata and Liquid.
- Integration tests with a local mock destination server that simulates 5xx, timeouts, redirects, and slow responses.
- Contract tests covering signature schemes per template (GitHub, Stripe, generic) using fixtures from the actual provider docs.
- Chaos test: kill a worker mid-dispatch, assert idempotent recovery without duplicate posts.

## Rollout
- Feature flag staged: staff servers, then 100 beta servers, then 100 percent.
- Each stage 72 hours with no regression required.
- Kill switch disables enqueueing new runs and freezes dispatch; in-flight runs complete normally.

## Open Items for v1.1
- Branching pipelines (multiple destinations from one trigger).
- OAuth-based outbound auth (GitHub Apps, Stripe Connect).
- Community template marketplace with submission and review flow.
- Webhook delivery analytics surfaced via the Analytics API.
