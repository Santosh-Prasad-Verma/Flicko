# APPFLOW: No-Code Bot Builder

## Flow A: First Bot Creation
1. Admin opens `bots.flicko.app`. Supabase JWT cookie verifies session.
2. Left rail loads bot list via `GET /api/v1/bots?server_id=X`. Returns empty array.
3. Empty state shows three template cards: Welcome, Mod, Reaction Roles.
4. Admin clicks "Welcome Bot" template. SPA loads canned DSL into the canvas (member_joined trigger plus send_dm action).
5. Admin edits the DM body in node inspector. Zustand store mutates the DSL JSON. Save button enables.
6. Admin clicks Save. SPA calls `POST /api/v1/bots/` with body `{server_id, name, dsl}`.
7. Backend validates DSL against JSON Schema. Inserts row into `bot_dsl_configs` (version 1) and `bot_dsl_revisions`. Returns 201 with bot id.
8. SPA navigates to `/bots/:id`. Toggle is "Paused" by default.
9. Admin flips the enable toggle. SPA calls `POST /api/v1/bots/:id/enable`. Trigger bus refreshes index within 30 seconds.
10. New member joins the server. Trigger bus matches `member_joined` for that server, queues a run.
11. Worker picks up the job, builds RunContext, executes nodes in topo order. send_dm action calls internal messaging API as the bot identity.
12. Per-node logs persisted to `bot_run_logs`. Run status set to success in `bot_runs`.
13. Admin sees the run in Run Logs tab within 2 seconds (Centrifugo push).

## Flow B: Branching Logic
1. Admin builds a mod bot: message_created → branch_if (contains profanity) → true edge to delete_message and add_role mute → false edge to end.
2. Save validates that branch_if has both `true` and `false` outgoing handles connected.
3. At runtime, evaluator runs the branch_if action. Output is a bool. Evaluator picks the matching outgoing edge by `source_handle`.
4. If true edge runs delete_message which calls internal API to remove the offending message, then add_role to mute author.

## Flow C: Run Failure
1. Action fails (e.g. role missing). Action returns error.
2. Evaluator captures error, marks run status `failed`, persists error to `bot_runs.error`.
3. Run halts (no further nodes execute).
4. UI shows red pill in run logs. Admin clicks, sees per-node trace; failing node is highlighted.
5. Prometheus increments `bot_evaluator_errors_total{type="role_missing"}`.

## Flow D: Rollback
1. Admin opens version dropdown, picks revision 7.
2. SPA shows preview-only canvas for that revision.
3. Admin clicks "Restore". Confirmation modal.
4. SPA calls `POST /api/v1/bots/:id/rollback` with `{version: 7}`.
5. Backend reads revision 7 DSL, inserts as new revision (version 12 if previous was 11), updates `bot_dsl_configs`.
6. Trigger bus picks up the new index on next refresh.

## Flow E: Test Run
1. Admin clicks Test tab. Picks trigger type, fills synthetic payload.
2. SPA calls `POST /api/v1/bots/:id/test` with `{trigger: {...}}`.
3. Backend evaluator runs in dry-run mode: action implementations short-circuit and return mocked outputs.
4. Per-node trace returned in response body. Not persisted to `bot_runs`.
5. UI renders accordion view with each node's input and output.

## Flow F: Rate Limit Hit
1. Bot fires 1001 times in an hour on a Pro tier server.
2. Token bucket rejects the 1001st run.
3. Bot run row inserted with status `rate_limited`.
4. Admin sees a banner "Bot has hit rate limit, runs paused for 12 minutes". Flicko notification sent.

## Flow G: Mobile Companion
1. Admin opens mobile app, navigates to Server Settings, taps "Bots".
2. App calls `GET /api/v1/bots?server_id=X` and renders list.
3. Tap a bot to see read-only run logs (last 50). Pause/resume toggle exposed.
4. Tap "Edit" opens a deep link to the SPA in the system browser.

## Trigger Sources
- Message events come from the existing message ingest pipeline. After a message is persisted, an internal NATS publish to `messages.created` carries the event payload to the trigger bus.
- Member events from the membership service.
- Voice events from the voice gateway.
- Cron triggers from a dedicated scheduler that ticks each minute and matches cron expressions in `bot_dsl_configs` where `dsl->triggers->cron` is set.

## Concurrency Model
- Each bot has at most 4 concurrent runs. Excess events queue up to 100, then drop with metric `bot_queue_dropped_total`.
- Worker pool is server-wide; busy bots do not starve idle ones because dispatcher round-robins per server.

## Failure Recovery
- If the evaluator crashes mid-run, defer block marks `bot_runs.status='crashed'` and writes panic to `bot_run_logs.error`.
- A reconciler job runs every 5 minutes, marks any `running` rows older than 60 seconds as `orphaned` so dashboards stay clean.
