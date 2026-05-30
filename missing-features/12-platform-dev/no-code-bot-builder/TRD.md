# TRD: No-Code Bot Builder

## Architecture
Three components.

1. **Bot Builder SPA** at `bot-builder/` (Vite plus React plus React Flow plus Zustand). Hosted at `bots.flicko.app`. Authenticates via Supabase JWT cookie. Saves DSL to backend over REST.
2. **DSL Evaluator** in Go at `backend/internal/bots/evaluator/`. Pure function from `(BotDSL, TriggerEvent) → []Action`. No reflection, no plugin loader.
3. **Trigger Bus** at `backend/internal/bots/triggers/`. Subscribes to internal NATS subjects (`messages.created`, `members.joined`, etc) and fans out matching bot runs to a Go worker pool.

## DSL Schema
JSON document, version pinned. Top level fields: `version` (int), `name` (string), `nodes` (array), `edges` (array), `variables` (object). Each node has `id`, `type`, `params`, `position`. Each edge has `source`, `target`, `source_handle` (default, true, false). The evaluator topo-sorts the graph at save time, rejects cycles unless explicitly inside a `wait` node.

## Storage
- `bot_dsl_configs` table holds latest revision per bot (id, server_id, name, dsl_json, version, enabled, created_by, created_at, updated_at).
- `bot_dsl_revisions` holds history (bot_id, version, dsl_json, author_id, created_at). Append only.
- `bot_runs` holds one row per execution (id, bot_id, trigger_event, status, started_at, ended_at, error).
- `bot_run_logs` holds per-node trace (run_id, node_id, input, output, duration_ms, error).

## Evaluator Limits
- Max 50 node executions per run. Counter incremented before each node.
- 5 second wall clock per run, enforced via `context.WithTimeout`.
- 8 MB max output buffer.
- No outbound network from inside the evaluator. The only side effects are Flicko internal API calls (send_message, add_role, etc) routed through a server-scoped client.
- Variables are typed: string, int, bool, list of string. No nested objects in v1.

## API
All routes under `/api/v1/bots/`.
- `POST /` create bot. Body: `{server_id, name, dsl}`.
- `GET /:id` fetch bot with latest DSL.
- `PUT /:id` save new DSL revision.
- `GET /:id/revisions` list revisions.
- `POST /:id/rollback` rollback to revision N.
- `POST /:id/enable` and `POST /:id/disable`.
- `GET /:id/runs` paginated runs with filter by status.
- `GET /:id/runs/:run_id/logs` per-node trace.
- `POST /:id/test` synthetic trigger for editor preview, evaluator runs in dry-run mode (no side effects).

## Trigger Bus
A central goroutine `triggerDispatcher` consumes NATS subjects. For each event it queries an in-memory index (`map[server_id]map[trigger_type][]bot_id`) refreshed from Postgres on a 30 second tick or on bot save. Matched bots are pushed to a buffered worker pool (default 64 workers per node, configurable). The pool applies per-server token bucket (1000 per hour Pro tier) and per-bot concurrency cap (4).

## Action Layer
Each action implements `Action` interface (`Execute(ctx, RunContext, Params) (Output, error)`). Actions live in `backend/internal/bots/actions/`. The action registry is built at boot. Custom actions cannot be registered at runtime, only at compile time, to keep the security surface small.

## Frontend
- React Flow for node graph.
- Zustand store mirrors DSL JSON, autosave debounced 1 second.
- Node palette is searchable, grouped by triggers, control flow, server actions, member actions, utility.
- Inline parameter editor: text inputs, select for roles and channels, code editor (Monaco) for templated strings using `{{variable}}` syntax.
- Save sends full DSL; backend computes diff against previous revision for the audit log.
- Live test pane runs `POST /:id/test` and displays per-node output.

## Security
- All routes require `bot.manage` permission on the server.
- DSL JSON is validated with a JSON Schema before persist. Unknown node types rejected.
- Templated strings are sandboxed with a minimal interpolator; no Sprig, no Go templates. Only `{{var.name}}` and `{{trigger.field}}` are allowed.
- Audit log entry written for every save, enable, disable, rollback.

## Observability
- Prometheus metrics: `bot_runs_total{status}`, `bot_run_duration_seconds{bot_id}`, `bot_node_duration_seconds{node_type}`, `bot_evaluator_errors_total`.
- Structured zap logs with `run_id` correlation.
- Distributed trace span per run, propagated to action layer.

## Migration 243
Adds the four tables above plus indexes on `bot_runs(bot_id, started_at desc)` and `bot_dsl_configs(server_id, enabled)`.

## Performance Targets
- Trigger to first node execution under 50 ms p95.
- Full chain of 5 nodes under 400 ms p95.
- Editor save round trip under 200 ms p95.
- Builder SPA initial load under 2 seconds on cable.
