# Disappearing Messages — Technical Requirements

## 1. Architecture Overview

```
   ┌────────┐  send w/ ttl   ┌──────────────┐
   │ Mobile │───────────────▶│  Messages    │
   │ Flutter│                │  handler     │
   └────────┘                └──────┬───────┘
                                    │ insert (expires_at)
                                    ▼
                           ┌────────────────┐
                           │  messages      │
                           │  + expires_at  │
                           └────────┬───────┘
                                    │
                  every 60s         │
   ┌──────────────────┐  pg_cron   ▼
   │  ephemeral_      │◀───────────┤
   │  sweeper job     │            │
   └────────┬─────────┘            │
            │ hard-delete row      │
            ▼                      ▼
   ┌──────────────┐       ┌──────────────┐
   │ Appwrite     │       │  Centrifugo  │
   │ (attachments)│       │ message.del  │
   └──────────────┘       └──────────────┘
```

## 2. Components

### Backend (Go) — extends existing messages module

- **Service:** `internal/services/privacy/disappearing_messages/service.go`
- **Worker:** `internal/services/privacy/disappearing_messages/sweeper.go` (pg_cron-triggered HTTP endpoint OR pure SQL function)
- **Handler patches:** `internal/handlers/messages_handler.go` accepts `ttl_seconds` field
- **Models:** add `ExpiresAt *time.Time` to `Message`

### Mobile (Flutter)

- **Feature folder:** `mobile/lib/features/privacy/disappearing_messages/`
  - `domain/`: `MessageTtl` enum
  - `application/`: `ttl_picker_provider.dart`
  - `presentation/`: `TtlPickerSheet`, `EphemeralBadge`, `CountdownChip`

The composer in `features/messaging/presentation/message_composer.dart` is patched to expose the picker.

### Infra
- DB: Postgres (Supabase). New column `expires_at` on `messages`. Index `(expires_at) WHERE expires_at IS NOT NULL`.
- pg_cron: `SELECT cron.schedule('disappearing_sweep', '* * * * *', $$ SELECT sweep_expired_messages(); $$);`
- Realtime: Centrifugo `channel:<id>` event `message.deleted` with `{message_id, reason: "expired"}`.
- Cache: invalidate `channel:<id>:messages` Redis keys on delete.
- Storage: Appwrite — attachments deleted by sweeper before message row removed.
- Search: Meilisearch — `message.deleted` event triggers index removal via NATS subject `flicko.search.delete`.

## 3. API Contracts

### REST (extension of existing messages)
```
POST /api/v1/messages
   body: { channel_id, content, ttl_seconds?: 300 | 3600 | 86400 | 604800 }
   response: { id, expires_at, ... }

GET /api/v1/messages/:id  → 410 Gone if expired
```

### WebSocket / Centrifugo
- Channel: existing `channel:<id>`
- Event: `message.deleted` payload `{ id, reason: "expired" | "user" | "mod" }`

### Payloads
```jsonc
// send ephemeral
{ "channel_id": "uuid", "content": "code: 4827", "ttl_seconds": 300 }

// response
{
  "id": "uuid",
  "channel_id": "uuid",
  "content": "code: 4827",
  "created_at": "2026-05-29T14:00:00Z",
  "expires_at": "2026-05-29T14:05:00Z"
}
```

## 4. Permissions & Auth

- Sender owns the TTL choice. Mods cannot extend or shorten a per-message TTL — that would be a content modification surface and out of scope.
- Server admin can globally disable disappearing messages for legal-hold reasons (`server_settings.disable_disappearing_messages`).
- RLS on `messages` already restricts read; nothing changes for writes.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 send latency overhead | <5 ms over baseline |
| Sweep lag (expires_at → row gone) | <90s p99 |
| Sweep batch size | 5k rows / minute / shard |
| Throughput (sends/sec) | 5k |
| Availability | 99.9% |
| Storage saved | linear with adoption |
| Worker idempotency | required |

## 6. Dependencies

- Existing `messages` table and module.
- Centrifugo publisher for `message.deleted`.
- pg_cron extension on Supabase Postgres.
- Appwrite SDK for attachment delete.
- New libs: none.

## 7. Observability

- Metrics: `flicko_ephemeral_msg_sent_total{ttl_bucket}`, `flicko_ephemeral_msg_swept_total`, `flicko_ephemeral_sweeper_duration_seconds` (histogram), `flicko_ephemeral_sweeper_lag_seconds`.
- Logs: sweep job logs `{run_id, swept_count, duration_ms}`. **Never log message content.**
- Traces: OTel span on each sweep run.
- Alerts: lag > 5min triggers PagerDuty.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Sweeper job stalls | messages outlive TTL | health-check cron; alert at 5min lag; manual trigger endpoint |
| Attachment delete fails | orphaned files in Appwrite | DLQ + nightly orphan-scrub job |
| Realtime publish fails | clients show stale message | idempotent fetch on reconnect; client checks `expires_at` and self-deletes |
| Clock skew | client shows wrong countdown | server-time sync ping; treat client-side as approximate |
| Replication lag (read-replica) | reader sees deleted msg briefly | sub-100ms replica lag is acceptable; final read goes to primary on cache miss |

## 9. Threat Model

**Attackers**
- A1: Recipient screenshots before TTL expires. Mitigation: out of scope here; `screen-capture-protection` covers it.
- A2: Recipient self-hosts a logging client and saves all messages. Mitigation: documented limitation. We cannot prevent a malicious endpoint from keeping plaintext.
- A3: Database forensics post-delete. Mitigation: hard delete + autovacuum after sweep; no soft-delete tombstone with content. Only metadata (`{id, expired_at}`) retained for audit-log integrity.
- A4: Mod attempts to recover message via DB read. Mitigation: rows are physically gone, audit-log lacks content; the only artifact is "a message expired."
- A5: Adversary delays sweeper. Mitigation: independent monitoring job verifies expected vs actual deletes.

**Assets**
- Message content with TTL set.
- Attachments referenced by ephemeral messages.

**Limitations (documented for users)**
- Receiver client can copy text; we cannot stop that.
- DMs being end-to-end encrypted is a separate scope (`encrypted-voice` covers voice; text DM E2EE is a separate roadmap item).
- Backups outside Flicko (e.g., user takes a screenshot) are out of scope.
