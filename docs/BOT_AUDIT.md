# Bot Ecosystem Audit — Production Readiness Report

> Senior Staff / Platform Architect review of the entire bot subsystem.
> Scope: backend bots, command router, event bus, realtime bridge, mobile integration, schemas, queue workers, webhook delivery.

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Root Causes — Why Bots Don't Work](#root-causes--why-bots-dont-work)
  - [A. Recovery Loop Re-registers Every Bot Every 2s](#a-recovery-loop-re-registers-every-bot-every-2s)
  - [B. Schema Mismatch Between Go Code and Deployed DB](#b-schema-mismatch-between-go-code-and-deployed-db)
  - [C. Nothing Publishes Events Into the Bot Bus](#c-nothing-publishes-events-into-the-bot-bus)
- [Issue Catalog](#issue-catalog)
  - [Critical](#critical)
  - [High](#high)
  - [Medium](#medium)
  - [Low](#low)
- [Architectural Assessment](#architectural-assessment)
- [Health Scores](#health-scores)
- [Priority Fix Order](#priority-fix-order)
- [Missing Discord-Level Features](#missing-discord-level-features)
- [Recommended Architecture Redesign](#recommended-architecture-redesign)
- [Final Verdict](#final-verdict)

---

## Executive Summary

The bot ecosystem is **not production-ready**. There are three independent show-stopping defects, any one of which alone explains the symptoms reported (bots not activating, commands failing, events not triggering, automation broken, slash commands not working, tickets failing, welcome silent). All three are present simultaneously.

In addition there are 15+ Critical and High-severity bugs spanning data integrity (schema drift), security (privilege escalation in config commands, public ticket channels, XP spoofing), reliability (panic-prone code paths in ticker handlers and warning escalation), and scalability (in-memory single-pod event bus, unbounded webhook goroutines, dead worker pool).

**Overall Bot System Health: 17 / 100**

</br>

## Root Causes — Why Bots Don't Work

### A. Recovery Loop Re-registers Every Bot Every 2s

**File:** `backend/internal/bots/registry.go` (lines 67–90)

```go
func (r *Registry) startWithRecovery(name string, bot Bot) {
    go func() {
        for {
            func() {
                defer func() { /* recover */ }()
                if err := bot.Register(r.ctx); err != nil { ... }
            }()
            time.Sleep(2 * time.Second) // <-- runs forever, not gated on a panic
        }
    }()
}
```

`Register(ctx)` is one-shot — it appends slash commands to `Router.definitions`, calls `EventBus.Subscribe(...)` (which always appends, never deduplicates), and spawns ticker goroutines (`autoCloseLoop`, `punishmentExpiryLoop`).

**After N seconds of uptime:**
- ~`N/2` duplicate subscribers per event type. After 1 hour: ~1800 handlers per event. One `MESSAGE_CREATE` from one user runs AutoMod 1800×, Leveling 1800× → 1800 `INSERT`s into `user_xp`, 1800 `DELETE`s on every profanity hit.
- `Router.definitions` grows linearly forever; `GET /api/v1/commands` returns the same command 1800 times.
- N ticker goroutines per bot. The previous iteration's `b.cancel` is overwritten by the next `Register`, so old goroutines are unreachable but still alive — memory leak.

**Fix:**

```go
func (r *Registry) startWithRecovery(name string, bot Bot) {
    if err := bot.Register(r.ctx); err != nil {
        r.logger.Error("bot register failed",
            zap.String("bot", name), zap.Error(err))
    }
    // Bots that need a long-running loop should expose Run(ctx).
    // Wrap Run with recovery, NOT Register.
}
```

Also patch `EventBus.Subscribe` to enforce uniqueness on `(eventType, name)`:

```go
func (eb *EventBus) Subscribe(t EventType, name string, h Handler) {
    eb.mu.Lock(); defer eb.mu.Unlock()
    list := eb.subscribers[t]
    for i, e := range list {
        if e.Name == name { list[i].Handler = h; return }
    }
    eb.subscribers[t] = append(list, HandlerEntry{name, h})
}
```

</br>

### B. Schema Mismatch Between Go Code and Deployed DB

There are **two parallel migration trees** that disagree:

- `backend/migrations/*.sql` — what the Go bot code targets.
- `supabase/migrations/*.sql` — what is actually deployed (mobile reads/writes via Supabase directly).

| Bot DB call | Bot expects | Actual schema (Supabase) | Effect |
|---|---|---|---|
| `audit_logs` (every moderation action) | `(server_id, moderator_id, target_id, action, reason)` | `(server_id, actor_id, action_type, target_type, target_id, reason, changes)` — `032_moderation_domain_tables.sql`, partitioned in `133` | Every audit log insert silently fails. `/modlog` always returns "No moderation logs found." |
| `polls` (`PollBot.createPoll`, `quickpoll`) | `(server_id, channel_id, creator_id, question, anonymous, multi_vote, status)` | `(message_id NOT NULL, channel_id, creator_id, question, allow_multiselect, expires_at, ended_at)` — `040_polls.sql` | `/poll create` and `/quickpoll` always 500. |
| `interactions` (`BotHandler.InvokeCommand`) | `(command_name, user_id, server_id, channel_id, options, status)` | `(application_id, type, guild_id, channel_id, user_id, token, data, version, responded)` — `054_phase2_rich_experience_tables.sql` | Every slash invoke logs an error and falls back to a fake `temp-…` ID; the follow-up `UPDATE` does nothing. No interaction history. |
| `messages` (every bot's `sendBotMessage`) | `INSERT (channel_id, content, type, created_at)` — no `user_id` | `user_id NOT NULL`; `type` constrained enum that does not include `'system'` literally | Every system/bot-authored message fails to insert: welcome greetings, ticket channel intro, auto-close notice, level-up message, starboard repost, transcript dump. |
| `member_roles` upsert | direct `INSERT ON CONFLICT DO NOTHING` | exists but RLS may block service-role insert | Auto-role assignment silently no-ops. |

**Fix:** Pick one source of truth (Supabase, since the mobile app talks to it directly). Then either rewrite the bot SQL to match, or migrate the schema. Add a CI test that boots Postgres, applies the canonical migration set, and runs every bot SQL through `EXPLAIN`/dry-run to detect schema drift.

</br>

### C. Nothing Publishes Events Into the Bot Bus

The bots subscribe to `MESSAGE_CREATE`, `MEMBER_JOIN`, `MEMBER_LEAVE`, `REACTION_ADD/REMOVE`, `BUTTON_CLICK`, `MODAL_SUBMIT`, `COMMAND_INVOKE`. The only producers of those events are:

1. `BotHandler.NotifyMemberJoin` / `NotifyMemberLeave` / `NotifyMessageCreate` / `NotifyReactionAdd` / `NotifyReactionRemove` / `InvokeCommand` (HTTP endpoints in `backend/internal/handlers/bot_handler.go`).
2. The `TickerMinute` / `TickerHour` background loop in `main.go`.

**The mobile client does not call any of those endpoints.** Confirmed via grep:

- `messages/notify`, `join-notify`, `leave-notify`, `add-notify`, `commands/invoke`, `slash`, `notifyMember`, `automod`, `welcome` across `mobile/**/*.dart` → **0 matches**.
- `bots_settings_screen.dart` and `bot_marketplace_screen.dart` only read/write Supabase tables directly.
- `bot_marketplace_data.dart` is a hardcoded list of fake AI skills.

WS-gateway / msg-service publish to Redis Pub/Sub topics (`rt:channel:<id>`) but **nothing** in the backend bridges those into `events.EventBus`.

**So:**
- User joins → no `MEMBER_JOIN` → WelcomeBot never greets, never autoroles.
- User sends message → no `MESSAGE_CREATE` → AutoMod never filters, Leveling never grants XP.
- User reacts → no `REACTION_ADD` → Starboard never fires.
- User wants `/ticket new` → there is no slash-command UI in the mobile client. No picker, no autocomplete, no modal. The endpoint exists but nothing invokes it.

**Fix options** (pick one):

1. **Postgres triggers + LISTEN/NOTIFY.** `AFTER INSERT` triggers on `server_members`, `messages`, `message_reactions` call `pg_notify('flicko.events', json_payload)`; backend `LISTEN`s and republishes into `EventBus`. Idempotent, lowest latency, zero client trust.
2. **Redis Pub/Sub bridge.** Subscribe to `rt:channel:*` in the backend, translate to bot events, publish.
3. **Client notify.** Have mobile/web call notify endpoints. Less reliable; clients can omit, spoof, or be offline.

Build a real slash-command UI on mobile in parallel: command picker driven by `GET /api/v1/commands`, modal renderer for `MODAL_SUBMIT`, ephemeral inline rendering for private responses.

---

## Issue Catalog

### Critical

| ID | Title | File(s) | Fix Cost |
|---|---|---|---|
| **CRIT-1** | Bots re-registered every 2s in unbounded loop | `backend/internal/bots/registry.go:67-90` | S |
| **CRIT-2** | `EventBus.Subscribe` has no dedup; subscribers leak forever | `backend/internal/events/bus.go:46-56` | S |
| **CRIT-3** | `audit_logs` schema mismatch — every audit insert fails | `backend/internal/bots/moderation.go`, `automod.go` | M |
| **CRIT-4** | `polls` schema mismatch — `/poll create` always 500s | `backend/internal/bots/poll.go:88-130` | M |
| **CRIT-5** | `interactions` schema mismatch — every slash invoke errors | `backend/internal/handlers/bot_handler.go:90-103` | M |
| **CRIT-6** | Bots insert into `messages` without `user_id`, type=`'system'` | every bot's `sendBotMessage` | M |
| **CRIT-7** | Mobile never publishes events into the bot bus | `mobile/**/*.dart` | XL |
| **CRIT-8** | `InvokeCommand` runs every command twice | `bot_handler.go:130-145` | S |
| **CRIT-9** | Asynq bot worker handlers (`bot:move`, `ludo_bot:move`) never registered | `main.go`, `asynq_coordinator.go` | S |
| **CRIT-10** | `bots/delivery` worker pool / circuit breaker is dead code | `backend/internal/bots/delivery/*` | M |
| **CRIT-11** | `router.go:122` un-checked type assertion will panic | `commands/router.go` | S |
| **CRIT-12** | `checkWarningEscalation` calls handlers with nil `ctx.Ctx` → panic | `bots/moderation.go` | S |
| **CRIT-13** | Tickets create public channels — no permission overwrites | `bots/ticket.go:120-138` | M |
| **CRIT-14** | `/messages/notify` — XP and automod spoofing endpoint | `bot_handler.go:640-684` | S |
| **CRIT-15** | Welcome / Ticket / Starboard / Music config commands have no permission gating | multiple bot files | S |

#### CRIT-1 — Bots re-registered every 2s

- **Severity:** Critical
- **File:** `backend/internal/bots/registry.go:67-90`
- **Root cause:** `for { Register(...); sleep 2s }` instead of one-shot register + recovery-wrapped Run loop.
- **Repro:** Boot backend; `for i in {1..10}; do curl /api/v1/commands; done` → response grows by 8 commands every 2s. Send one `MESSAGE_CREATE` after 60s of uptime → ~30 INSERTs into `user_xp`.
- **Impact:** Memory leak; every event processed N times; rate limits bypassed; all "duplicated listeners" / "inconsistent state" symptoms downstream.
- **Fix:** See section A above.

#### CRIT-2 — `EventBus.Subscribe` no dedup

- **Severity:** Critical
- **File:** `backend/internal/events/bus.go:46-56`
- **Root cause:** `eb.subscribers[t] = append(...)` without checking for an existing entry with the same `name`.
- **Fix:** See section A above.

#### CRIT-3 — `audit_logs` schema mismatch

- **Severity:** Critical
- **Files:** `backend/internal/bots/moderation.go` (`logAudit`, `/modlog` query), `backend/internal/bots/automod.go` (`takeAction`)
- **Root cause:** Bot SQL targets `(moderator_id, target_id, action, reason)`; deployed schema is `(actor_id, action_type, target_type, target_id, reason, changes)` and is now partitioned (`133_partition_audit_logs.sql`).
- **Repro:** `/kick @user reason`, then `/modlog` → empty.
- **Fix:**
  ```sql
  INSERT INTO audit_logs (server_id, actor_id, action_type, target_type, target_id, reason)
  VALUES ($1, $2, $3, 'user', $4, $5)
  ```

#### CRIT-4 — `polls` schema mismatch

- **Severity:** Critical
- **File:** `backend/internal/bots/poll.go:88-130`
- **Root cause:** Insert references `server_id, anonymous, multi_vote, status` — none exist on `public.polls`. `message_id` is `NOT NULL` but never provided.
- **Fix:** Post the announcement message first to get its ID, then create the poll attached to it. Or migrate the schema. Pick the deployed-schema path (already integrated with mobile).

#### CRIT-5 — `interactions` schema mismatch

- **Severity:** Critical
- **File:** `backend/internal/handlers/bot_handler.go:90-103`
- **Root cause:** Insert uses `(command_name, user_id, server_id, channel_id, options, status)`; real schema is `(application_id, type, guild_id, channel_id, user_id, token, data, version, responded)`.
- **Impact:** Every command invocation logs `"interaction insert failed"`; downstream `UPDATE interactions SET status = 'completed'` against the fake `temp-…` ID does nothing.
- **Fix:**
  ```sql
  INSERT INTO interactions (type, guild_id, channel_id, user_id, data)
  VALUES (2, $1, $2, $3, jsonb_build_object('name', $4, 'options', $5))
  RETURNING id, token
  ```

#### CRIT-6 — `messages` insert shape

- **Severity:** Critical
- **Files:** `welcome.go`, `ticket.go`, `leveling.go`, `starboard.go`, `automod.go`, etc.
- **Root cause:** Deployed `messages` schema requires `user_id NOT NULL`, and `type` typically does not allow `'system'` literally.
- **Impact:** Every system/bot-authored message fails: welcome greetings, ticket channel intro, auto-close notice, level-up, starboard repost, transcript.
- **Fix:** Provision a stable system bot user (seeded UUID), use it as `user_id`. Route inserts through `MessageHandler.CreateMessage` (with service-key auth) so mention/attachment/pin hooks run.

#### CRIT-7 — Mobile never publishes events

- **Severity:** Critical
- **Files:** `mobile/**/*.dart`
- **Root cause:** Mobile uses Supabase directly for `server_members`/`messages`/`message_reactions` writes. No call to the `/api/v1/.../*-notify` endpoints. No slash-command UI either.
- **Impact:** Welcome / leave / automod / leveling / starboard never trigger from real activity. Largest cause of "bots not activating".
- **Fix:** See section C above.

#### CRIT-8 — Every command runs twice

- **Severity:** Critical
- **File:** `backend/internal/handlers/bot_handler.go:130-145`
- **Root cause:** `eventBus.Publish(evt)` triggers the `mod-commands` subscriber which calls `router.HandleEvent`; immediately after, `executeCommand(...)` calls `router.HandleEvent` again.
- **Impact:** `/ban @u` bans twice. `/ticket new` creates two tickets. `/play X` queues two copies. Every audit log doubled.
- **Fix:** Pick one execution path. The publish should be a fan-out *signal* for analytics/external bots; execution goes through the router directly.

#### CRIT-9 — Asynq handlers not registered

- **Severity:** Critical
- **Files:** `backend/internal/bots/asynq_coordinator.go`, `backend/cmd/server/main.go`
- **Root cause:** `EnqueueBotMove` / `EnqueueLudoBotMove` push tasks. No `asynq.NewServer` + `mux.HandleFunc(TypeBotMove, ...)` is wired anywhere in the running services.
- **Impact:** Chess and Ludo bot moves never execute in production. The fallback in-memory `botCoordinator` (in `gaming/module.go`) loses moves on pod restart.
- **Fix:**
  ```go
  asynqSrv := asynq.NewServer(
      asynq.RedisClientOpt{Addr: cfg.RedisAddr},
      asynq.Config{Concurrency: 16},
  )
  mux := asynq.NewServeMux()
  mux.HandleFunc(bots.TypeBotMove,     coord.HandleBotMoveTask)
  mux.HandleFunc(bots.TypeLudoBotMove, coord.HandleLudoBotMoveTask)
  go asynqSrv.Run(mux)
  ```

#### CRIT-10 — Dead delivery package

- **Severity:** Critical (for external bots)
- **Files:** `backend/internal/bots/delivery/{worker_pool,retry,circuit_breaker}.go`
- **Root cause:** Nothing instantiates `delivery.NewWorkerPool`. External bot delivery instead uses the simpler `WebhookDelivery` in `webhook.go` — no circuit breaker, unbounded goroutines, no shared rate-limit.
- **Fix:** Wire `delivery.WorkerPool` into `ExternalBotManager`. Cap workers to `runtime.NumCPU()*4`; queue 10k. Remove the ad-hoc loop in `webhook.go`.

#### CRIT-11 — Un-checked type assertion will panic

- **Severity:** Critical
- **File:** `backend/internal/commands/router.go:122` — `InteractionID: evt.Data["interaction_id"].(string)`
- **Fix:** `id, _ := evt.Data["interaction_id"].(string)`.

#### CRIT-12 — `checkWarningEscalation` builds `CommandContext` without `Ctx` → panic

- **Severity:** Critical
- **File:** `backend/internal/bots/moderation.go` — `checkWarningEscalation`
- **Root cause:** Passes `commands.CommandContext{ServerID, UserID, Options}` (no `Ctx`). Inside `handleKick`, `context.WithTimeout(ctx.Ctx, ...)` panics on nil parent.
- **Impact:** Crossing the warning threshold panics the moderation bot. Recovery loop (CRIT-1) restarts → another duplicate registration.
- **Fix:** `Ctx: context.Background()` and pass through.

#### CRIT-13 — Tickets create public channels

- **Severity:** Critical (privacy)
- **File:** `backend/internal/bots/ticket.go:120-138`
- **Root cause:** `INSERT INTO channels (server_id, name, type, created_at)` with no `is_private`, no permission overwrites.
- **Impact:** Support tickets — which contain PII, escalations, abuse reports — are world-readable to the entire server.
- **Fix:** Create with `is_private=true` and explicitly insert `channel_permission_overwrites`: `@everyone DENY VIEW_CHANNEL`, creator `ALLOW VIEW+SEND`, configured staff role `ALLOW VIEW+MANAGE`. Wrap channel + ticket inserts in a transaction.

#### CRIT-14 — `/messages/notify` is a free XP / spoofing endpoint

- **Severity:** Critical (security)
- **File:** `backend/internal/handlers/bot_handler.go:640-684`
- **Root cause:** Only validates that the caller is a member of the server. `message_id` and `content` accepted as-is. No verification that the message exists or that the calling user authored it.
- **Impact:**
  - Spam `POST /messages/notify` to gain unlimited XP.
  - Submit fake `content` containing slurs/phishing → AutoMod actions logged against the actual author.
  - DoS the bus.
- **Fix:** Look up the message server-side, verify `messages.user_id = auth.uid()` and `messages.channel_id = body.channel_id`, then publish.

#### CRIT-15 — Bot config commands lack permission gating

- **Severity:** Critical (security)
- **Files:** `welcome.go.handleWelcome`, `ticket.go.handleTicketConfig`, `starboard.go.handleStarboard`, `music.go.handleMusicConfig`
- **Root cause:** Permission gates exist only in `ModerationBot` and `LevelingBot`. Everyone else accepts `/welcome setup #channel` or `/ticket-config staff-role @whoever` from any member.
- **Impact:** Any member can change welcome channel, set autoroles, configure ticket staff, set DJ role. Privilege escalation.
- **Fix:** Centralize `requireManageGuild(ctx)` on `BotContext` and call at the top of every config command.

</br>

### High

| ID | Title | File(s) |
|---|---|---|
| **HIGH-1** | `Router.Register` mutates `definitions` unboundedly under recovery loop | `commands/router.go:96-103` |
| **HIGH-2** | TickerMinute / TickerHour fire globally; per-server bots iterate unfiltered, no shard lock | `main.go`, `bots/moderation.go` |
| **HIGH-3** | `MusicBot.handlePlay` race on position — no `UNIQUE(server_id, position)` | `bots/music.go` |
| **HIGH-4** | Tickets race on `ticket_number` (TOCTOU `MAX+1`) | `bots/ticket.go:140-152` |
| **HIGH-5** | `levelForXP` is O(level) per message — hot-path CPU | `bots/leveling.go:586-595` |
| **HIGH-6** | `getUsername` panics on empty userID (`userID[:8]`) | multiple bot files |
| **HIGH-7** | External bot subscriptions register under same name across 16 events → CRIT-1 amplified 16× | `bots/external_manager.go:277-287` |
| **HIGH-8** | `bridge.go` only handles 5 of ~25 event types — no command response bridge | `events/bridge.go` |
| **HIGH-9** | `WebhookDelivery` spawns one goroutine per (event × bot) without cap | `bots/webhook.go:58-80` |
| **HIGH-10** | `WebhookDelivery.logDelivery` synchronous DB write per attempt — floods Postgres | `bots/webhook.go:218-237` |
| **HIGH-11** | Mobile writes `enabled` directly to bot tables, bypassing permission service | `bots_settings_screen.dart` |
| **HIGH-12** | `BotHandler.UpdateBotSettings` only allows owner — co-admins blocked | `bot_handler.go:175-186` |
| **HIGH-13** | `/commands/invoke` no rate limit per user / per command | `main.go` |
| **HIGH-14** | No idempotency on notify endpoints — same `message_id` posted N times grants N×XP | `bot_handler.go` |
| **HIGH-15** | In-memory `botCoordinator` loses chess bot turns on pod death | `bots/coordinator.go`, `gaming/module.go` |
| **HIGH-16** | `/purge` doesn't publish `MESSAGE_DELETE_BULK` or invalidate read-state | `bots/moderation.go` |
| **HIGH-17** | `MusicBot.requireDJ` opens DJ control to everyone on transient DB error | `bots/music.go:71-90` |
| **HIGH-18** | `AutoMod.takeAction` raw `DELETE FROM messages` — bypasses message hooks (attachments, reactions, pins) | `bots/automod.go:330-336` |
| **HIGH-19** | External bot fan-out — no Redis cache of (botID → serverIDs); per-event DB JOIN | `bots/external_manager.go` |
| **HIGH-20** | `audit_logs` partition default is the only catch-all — no rolling partition creator | `supabase/migrations/133_partition_audit_logs.sql` |

</br>

### Medium

| ID | Title | File(s) |
|---|---|---|
| **MED-1** | `RecoveryMiddleware` swallows panics without surfacing an error | `events/middleware.go:13-23` |
| **MED-2** | `MusicBot.handlePlay` doesn't enforce `enabled` flag | `bots/music.go` |
| **MED-3** | Leveling cooldown defaults to 0 if `level_settings` not seeded — every message earns XP | `bots/leveling.go` |
| **MED-4** | `WelcomeBot.testWelcome` UX glitch — uses configured channel even though response is ephemeral | `bots/welcome.go` |
| **MED-5** | `BotHandler.sanitizeString` strips `<…>` indiscriminately — mangles `<#channelid>`, `<@userid>`, custom emoji | `bot_handler.go:746-771` |
| **MED-6** | `EventBus.Publish` allocates two slices per call — GC pressure under load | `events/bus.go:65-75` |
| **MED-7** | No transaction around (`channels` INSERT, `tickets` INSERT) → orphan channels on partial failure | `bots/ticket.go` |
| **MED-8** | `parseDuration` doesn't reject zero/negative durations | `bots/moderation.go` |
| **MED-9** | Two parallel HMAC implementations (`bots/auth/Signer` vs `webhook.go.generateSignature`) — header inconsistency risk | `bots/auth`, `bots/webhook.go` |
| **MED-10** | `processAutoClose` doesn't paginate — combined with CRIT-1, N concurrent sweeps over the same data | `bots/ticket.go` |
| **MED-11** | AutoMod mention regex `<@!?\w+>` undercounts UUIDs (hyphens) | `bots/automod.go:280` |
| **MED-12** | `WelcomeBot.onMemberJoin` race between `enabled` read and autorole loop | `bots/welcome.go` |
| **MED-13** | `UpdateBotSettings` doesn't validate bot exists in registry | `bot_handler.go` |
| **MED-14** | `MusicBot.shuffle` rewrites every row with `ROW_NUMBER OVER (ORDER BY random())` — fine at small scale | `bots/music.go` |
| **MED-15** | `internal/bots/auth` and `internal/bots/ratelimit` only referenced by dead `delivery` package | `bots/auth`, `bots/ratelimit` |

</br>

### Low

| ID | Title |
|---|---|
| **LOW-1** | Many bot handlers swallow `Scan` errors silently — observability gap |
| **LOW-2** | `Embed.Color` is a hex string — should be int (RGB), the way Discord does it |
| **LOW-3** | `BotContext` has no per-request tracing span — events don't appear in traces |

---

## Architectural Assessment

### Slash Command System

- **Backend:** Reasonable router. Sub-commands partially supported via `parent/sub` keys but the registration shape doesn't expose nested options to clients. Modals/forms not modeled (`MODAL_SUBMIT` event exists, no router/renderer). Autocomplete unimplemented. Ephemeral responses are a flag on `CommandResponse` but the bridge doesn't honor it (no ephemeral channel in Realtime).
- **Mobile:** Does not exist. No command picker, no autocomplete, no modal renderer. Bot UX cannot work without this.

### Event Listeners / Propagation

- `EventBus` is a single in-process map. Doesn't survive pod restart, doesn't multicast across pods. Mostly unfed (CRIT-7).
- Bridge to clients incomplete (HIGH-8).
- External bots get a flat fan-out with no permission cache (HIGH-19).

### Realtime / WebSocket Integration

- `services/ws-gateway` and `services/msg-service` are a separate, well-engineered Redis Pub/Sub stack. They do not participate in the bot bus. **Any production-grade bot system has to bridge these two worlds.**

### Ticket / Form Workflow System

- Single-step DB inserts. No modal flow, no multi-step state machine, no review/export endpoints for admins. The "user opens ticket → bot opens sequential modals → user fills → validate → store → admins review/export" flow does not exist. Only `/ticket new <subject>` plus a static system message.

### Welcome / Automation

- Plumbing exists but doesn't fire (CRIT-7). When it does, the `messages` insert fails (CRIT-6) and autorole insert fails on RLS. Auto-roles, verification screening, reaction roles, scheduled announcements, rule acceptance — defined as separate handlers but none route into bot events.

### Distributed Architecture / Scale

- Bus is in-process only. Multi-pod deployments have independent buses per pod. A `MEMBER_JOIN` posted to pod A will not fire WelcomeBot on pod B if the request lands on pod B.
- Tickers fire per pod → moderation expiry runs N×.
- Bot state (`temp_punishments`, `polls.expires_at`) is reconciled by polling, not scheduled jobs.
- Asynq is configured but only used by chess/ludo, and even that is only one direction (publish; no subscriber registered — CRIT-9).

### Observability

- No metrics for: events published per type, handler latency per (event, bot), command invoke success rate, webhook delivery failure rate per bot.
- `LoggingMiddleware` only warns on >500 ms.

---

## Health Scores

| Dimension | Score | Justification |
|---|---:|---|
| Stability | **18 / 100** | Recovery loop guarantees runaway resource leak; multiple guaranteed panics; double-execution of every command. |
| Scalability | **15 / 100** | In-memory bus, no shard/cluster fan-out, per-pod tickers, dead worker pool, no rate limiting on writes. |
| Performance | **30 / 100** | Linear loops in hot paths (level math), no caching, sub-select races, GC pressure from publish. |
| Security | **22 / 100** | Privilege escalation in welcome/ticket/starboard/music config; public ticket channels; XP spoofing; admin-only owner check. |
| Automation Quality | **12 / 100** | Welcome/automod/leveling/starboard never fire from real activity. Slash commands run twice. |
| Production Readiness | **8 / 100** | Cannot ship as-is. Slash commands have no mobile UI; the dominant trigger (events from messages/joins) is not wired. |
| **Overall Bot System Health** | **17 / 100** | |

---

## Priority Fix Order

### P0 — Unblock the core bus (1–2 days)

1. **CRIT-1, CRIT-2, HIGH-1** — Stop the recovery-loop re-registration and dedup the bus.
2. **CRIT-8** — Stop running every command twice.
3. **CRIT-11, CRIT-12, HIGH-6** — Fix the panic-prone code paths.

### P1 — Unblock the data layer (2–3 days)

4. **CRIT-3, CRIT-4, CRIT-5, CRIT-6** — Pick one schema and align Go SQL. Add a CI test that runs every bot SQL against the canonical schema.

### P2 — Wire the producers (3–5 days)

5. **CRIT-7** — Bridge events from `msg-service` / Supabase into `EventBus` (Postgres triggers + `LISTEN/NOTIFY` is the cleanest path).
6. **CRIT-9** — Register Asynq handlers for chess/ludo bot moves.
7. **CRIT-10** — Plug the dead `delivery` package into webhook fan-out.

### P3 — Lock down security (2 days)

8. **CRIT-13** — Ticket privacy (overwrites + transaction).
9. **CRIT-14** — `/messages/notify` author verification.
10. **CRIT-15** — Per-bot config command permission gating.
11. **HIGH-11, HIGH-12** — Mobile must call backend APIs; allow co-admins.

### P4 — Production hardening (ongoing)

12. **HIGH-2** — Distributed cron with Redis lock; replace ticker.
13. **HIGH-3, HIGH-4** — Add UNIQUE constraints / per-server sequences.
14. **HIGH-9, HIGH-10** — Webhook worker pool + buffered delivery logs.
15. **HIGH-13, HIGH-14** — Rate limiting + idempotency on notify endpoints.

---

## Missing Discord-Level Features

- **Modal/form open & submit pipeline.** `MODAL_SUBMIT` event type exists, no router/modal renderer/mobile UI.
- **Autocomplete.** No event type, no debounce, no per-command provider.
- **Ephemeral responses** propagated through Realtime as a private message stream.
- **Multi-step interaction tokens** (Discord's 15-min follow-up token model).
- **Message components** (buttons, select menus). `ActionRow` exists in the response but no rendering / round-trip handler on the client.
- **Workflow engine** for "user opens ticket → form A → form B → validate → store → notify staff → export."
- **Slash command picker UI** on mobile.
- **Reaction-role bot, scheduled announcements bot, AI/utility bot, server analytics bot, level/reputation bot** — none exist.
- **Audit log viewer** (admin UI for `audit_logs`).

---

## Recommended Architecture Redesign

### Event Bus

```
┌─────────────────┐       ┌──────────────┐       ┌──────────────┐
│  Postgres       │       │  Bus         │       │  Bots        │
│  (TRIGGER       │──────▶│  (NATS or    │──────▶│  (workers,   │
│   pg_notify)    │       │   Redis      │       │   Asynq)     │
└─────────────────┘       │   Streams)   │       └──────────────┘
                          └──────┬───────┘
┌─────────────────┐              │              ┌──────────────┐
│  msg-service    │──────────────┤              │  External    │
│  (publishes     │              │─────────────▶│  webhook     │
│   directly)     │              │              │  workers     │
└─────────────────┘              │              └──────────────┘
                                 ▼
                          ┌──────────────┐
                          │  ws-gateway  │
                          │  (rt fan-out)│
                          └──────────────┘
```

- **NATS JetStream** preferred over Redis Streams: durable, exactly-once with deduplication windows, native consumer groups. Redis Streams works too if you already pay the operational cost of Redis.
- One stream per event class (`flicko.events.message`, `flicko.events.member`, …), partitioned by `server_id` so a single server's events are ordered.
- Bots consume as durable consumers with retry policy and DLQ.

### Worker Architecture

- **Asynq for delayed/scheduled work** (chess bot moves, punishment expiry, scheduled announcements, ticket auto-close). One worker pool per queue priority (`critical`, `default`, `low`).
- **Redis-backed distributed cron** with leader-election lock for any sweep that must run exactly once cluster-wide.
- **Webhook delivery worker pool** (the existing `delivery` package, properly wired) — bounded concurrency, circuit breaker, exponential backoff with jitter.

### Realtime

- **ws-gateway stays as is** — Pub/Sub fan-out of channel events.
- Add a new realtime topic `rt:user:<userId>:interactions` for ephemeral command responses.
- Bot command responses → publish `INTERACTION_RESPONSE` to that topic → ws-gateway delivers privately to the requesting socket.

### Database

- One canonical schema. Delete `backend/migrations/002_bot_system_tables.sql` and `backend/migrations/062_bot_system_tables.sql` — keep the `supabase/migrations/*` tree as the single source of truth (since mobile depends on it).
- All bot writes go through service modules with RLS bypass via the service-role key, not raw `db.Exec` from the bot.
- Add foreign keys + cascades. Add UNIQUE constraints on `(server_id, position)` for queues, `(server_id, ticket_number)` for tickets.
- Partition `audit_logs`, `bot_webhook_deliveries`, and `user_xp` events by month with a rolling partition creator.

### Bot Framework Structure

```go
type Bot interface {
    Name() string
    Commands() []CommandDefinition
    Events() []EventSubscription
    Run(ctx context.Context) error // optional long-running loop
    Shutdown(ctx context.Context) error
}

type EventSubscription struct {
    Type    EventType
    Handler Handler
    Filter  *EventFilter // server, channel, role, user predicates
}
```

- Move all SQL into a per-bot repository (`bots/welcome/repo.go`) with interfaces — testable, mockable, schema-checked.
- Centralize permission checks in `BotContext.RequirePermission(serverID, userID, perm)`.

### Security

- **Per-bot install scopes** (Discord OAuth-style `bot.scope`). External bot can subscribe to `MESSAGE_CREATE` only if scope `messages.read` was granted at install.
- **Per-(user, command) rate limits** in Redis (token bucket).
- **Idempotency keys** on notify endpoints.
- **Author verification** server-side on every `*-notify` endpoint.
- **HMAC-signed webhook delivery** with replay-prevention nonce.

### Observability

- Prometheus metrics:
  - `flicko_bot_events_published_total{type}`
  - `flicko_bot_handler_duration_seconds{bot, event}`
  - `flicko_bot_command_invoke_total{command, status}`
  - `flicko_bot_webhook_delivery_total{bot, status}`
  - `flicko_bot_event_lag_seconds{type}` (publish→handle)
- OTel traces on every command invocation — propagate the trace context through the event bus.
- Structured logs with `bot`, `server_id`, `command`, `interaction_id` fields.

---

## Final Verdict

**The bot ecosystem is not production-ready.** It compiles, boots, and the surface looks complete on paper — every popular bot category (moderation, automod, welcome, leveling, ticket, music, poll, starboard) has a Go file with reasonable structure. But:

1. The core registration loop guarantees resource leak and N× event amplification.
2. Half the bot SQL targets a schema that doesn't exist in the deployed database.
3. The producers of bot events (mobile clients, msg-service, supabase) are not wired to the bot bus at all.
4. Slash commands have no client UI to invoke them.
5. Background workers for the chess/ludo bot are written but never registered.
6. Ticket privacy is broken; configuration commands are open to all members; XP can be spoofed via a public endpoint.

The fixes for the P0 and P1 categories are mechanical and can land in a week. The P2 category (event-producer bridge, mobile slash UI) is the substantive work — plan for 2–3 weeks of focused engineering. The redesign in section "Recommended Architecture Redesign" is the path to a Discord-scale system; that's a 1–2 quarter effort.

Until P0–P2 land, **do not enable bots in production**.
