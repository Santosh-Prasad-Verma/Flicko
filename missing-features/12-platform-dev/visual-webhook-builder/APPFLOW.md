# APPFLOW: Visual Webhook Builder

## Flow 1: Creating an Inbound Webhook from a Template
1. User clicks New Webhook on the list view, picks the GitHub template.
2. Frontend calls `POST /api/v1/webhooks` with `{server_id, template_id: "github-releases", direction: "inbound"}`.
3. Backend clones the template graph into a new `webhooks` row, generates a 32-byte verification secret, and returns the webhook with its public URL `https://flicko.app/api/v1/webhooks/in/{id}`.
4. Canvas opens with the trigger node selected; inspector prompts for the GitHub secret to be configured on the GitHub side.
5. User saves; backend validates topology and persists the graph.
6. User goes to GitHub repo settings, pastes the URL and secret, picks "release" event.
7. GitHub sends a ping; signature middleware verifies, run executes, the configured destination posts a message to the picked channel.

## Flow 2: Building a Custom Outbound Webhook
1. User picks "Start from scratch", selects Outbound direction.
2. Drags Trigger node "Message posted in #ops" onto canvas. Drags Transform node, links them. Drags HTTP Destination node, links it.
3. Configures Trigger: channel #ops. Configures Transform: JSONata `{ text: $.content, user: $.author.username }`. Configures Destination: URL, custom header `X-Auth: Bearer {{secret}}`.
4. Clicks Test, pastes a sample message JSON. Backend runs the pipeline against the payload, returns each node's output.
5. User reviews, fixes the JSONata expression, retests, then saves.
6. Backend persists the graph and starts subscribing to `message.created` events filtered by channel #ops.

## Flow 3: Inbound Delivery
1. External service POSTs to `/api/v1/webhooks/in/{id}` with body and `X-Flicko-Signature` header (or template-specific scheme).
2. Public endpoint applies per-IP and per-webhook rate limits.
3. Signature middleware computes HMAC, compares constant-time. Mismatch returns 401, increments mismatch counter, logs.
4. Body is validated against size cap (1 MB).
5. Handler inserts a `webhook_runs` row in `pending` state with the raw body, returns 202.
6. Worker dequeues using `FOR UPDATE SKIP LOCKED`, transitions to `running`, executes graph nodes in topological order.
7. On success, transitions to `succeeded`, records `output` and `duration_ms`.
8. On failure, transitions to `failed_retryable` (5xx) or `failed_permanent` (4xx) with retry policy.

## Flow 4: Outbound Dispatch
1. Existing event bus emits `message.created` with payload.
2. Webhook subscriber filters for active outbound webhooks matching the event type and channel.
3. For each match, inserts a run row.
4. Dispatcher worker picks the run, evaluates the graph, computes the body, signs with HMAC, and POSTs to the destination URL with `X-Flicko-Signature: t={ts},v1={hex}` and `X-Flicko-Timestamp`.
5. Records HTTP status and response body excerpt.
6. Retries on 5xx with exponential backoff up to 6 attempts.

## Flow 5: Test Run
1. User clicks Test in the canvas, pastes payload.
2. Frontend calls `POST /api/v1/webhooks/{id}/test` with `{payload}`.
3. Backend runs the graph synchronously with `dry_run=true`. Destination nodes do not actually fire; they return a simulated request preview.
4. Response includes per-node `{node_id, input, output, error?, duration_ms}`.
5. Frontend animates each node and surfaces results in the dock.

## Flow 6: Replay Failed Run
1. User opens Run History, sees a failed row, clicks Replay.
2. Frontend calls `POST /api/v1/webhooks/{id}/runs/{run_id}/replay`.
3. Backend duplicates the run row with a new id, sets `replay_of = original_run_id`, resets retry state, queues immediately.
4. Worker picks it up and dispatches.
5. UI subscribes to a websocket update channel and animates the new row to its terminal status.

## Flow 7: Bulk Replay
1. User clicks Replay All on the failed-runs banner.
2. Confirm dialog shows the count.
3. Frontend calls `POST /api/v1/webhooks/{id}/runs/replay-failed?since=...`.
4. Backend selects matching `failed_retryable` runs and resets their retry schedule with jitter spread over 60 seconds to avoid stampedes.
5. UI shows progress as runs transition.

## Flow 8: Secret Rotation
1. User clicks Rotate Secret in the inspector for a Trigger or Destination node.
2. Confirm dialog warns that current senders or receivers will need the new value.
3. Backend generates a new secret, encrypts and stores. The previous secret remains valid for a 24-hour grace window so callers have time to migrate.
4. Frontend reveals the new value once with a copy pill.
5. Audit log captures the rotation.

## Flow 9: Template Update
1. Operator publishes a new version of the GitHub template.
2. Webhooks based on the older version receive an in-app banner: "Template updated. Review changes."
3. User clicks Review; a side-by-side diff shows added or removed nodes.
4. User accepts; backend merges the template change into the user's graph, preserving custom field values where possible.
5. User declines; the existing graph keeps working unchanged.
