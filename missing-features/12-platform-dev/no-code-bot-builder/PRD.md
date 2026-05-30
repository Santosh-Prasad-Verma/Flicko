# PRD: No-Code Bot Builder

## Problem
Flicko server owners want custom bots (welcome messages, role assignment, moderation, polls, scheduled reminders) without writing Go or JavaScript. Current bots are hard-coded by the platform team. Server admins file feature requests and wait weeks for shipping. Power users on Discord/Slack expect drag-and-drop bot creation in minutes.

## Goal
Ship a visual bot builder where server admins compose bots from trigger and action nodes, connect them with edges, and deploy to their server in one click. Bots run on Flicko-hosted Go runtime with per-server isolation, rate limits, and audit logs.

## Non-Goals
- Arbitrary code execution (bots are pure DSL, no eval).
- Cross-server bot sharing in v1 (bots are scoped to one server).
- External HTTP calls from inside bot logic in v1 (use Zapier integration for that).
- Marketplace for community bots (post-launch roadmap).

## Users
- Server admin: builds and manages bots for their community.
- Server moderator: enables, disables, and inspects bot runs.
- Member: experiences the bot via auto-replies, role grants, etc.

## User Stories
- As an admin, I drag a "user joined" trigger onto the canvas, connect it to a "send DM" action, type a welcome message, and save. New members receive my DM within five seconds of joining.
- As an admin, I build a moderation bot that watches messages, runs them through a profanity filter node, and auto-deletes plus warns the author.
- As a moderator, I open the bot run history and see the last 100 executions with input, output, and error if any.
- As an admin, I duplicate an existing bot, tweak two nodes, and ship a variant for a sister server.

## Success Metrics
- 30 percent of paid servers ship at least one custom bot within 60 days of launch.
- Median bot build time under 8 minutes (first save).
- Bot runtime p95 under 400 ms for chains of fewer than five nodes.
- Zero security incidents from bot logic in the first quarter.

## Scope V1
- Canvas SPA with React Flow at `bot-builder/`.
- 12 trigger types: message_created, message_updated, member_joined, member_left, reaction_added, reaction_removed, role_changed, voice_joined, voice_left, scheduled_cron, slash_command, mention.
- 18 action types: send_message, send_dm, add_role, remove_role, kick, ban, mute, delete_message, react, pin, set_topic, create_thread, log_audit, increment_counter, branch_if, wait, set_variable, end.
- Branching with `branch_if` (compares variables, returns true/false edge).
- Per-server limits: 25 bots, 50 nodes per bot, 1000 runs per hour.
- Run logs retained 30 days, then archived to cold storage.
- Versioning: every save creates a new revision; admins can roll back.

## Risks
- DSL evaluator is a critical security boundary. A regex bug or unbounded loop could DoS the worker pool. Mitigated with hard CPU and memory ceilings per run, max 50 node executions per run, 5 second wall clock.
- Trigger fan-out for popular servers could swamp the queue. Mitigated by per-server token bucket and bot-level concurrency limits.
- Admins might leak secrets in DSL string templates. Mitigated by a secrets vault that DSL references by name only, never inline.

## Pricing Tier
Free servers: 2 bots, 200 runs per day. Pro: 25 bots, 1000 runs per hour. Enterprise: unlimited bots, custom rate limits.

## Launch Plan
- Week 1 to 4: backend evaluator, DSL schema, migrations 243.
- Week 5 to 7: SPA scaffolding, trigger and action node library.
- Week 8 to 9: run logs UI, versioning, rollback.
- Week 10: closed beta with 20 paid servers.
- Week 11 to 12: GA, docs, in-product tour.
