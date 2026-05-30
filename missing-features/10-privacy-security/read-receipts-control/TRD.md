# Read Receipts Control — Technical Requirements

## 1. Architecture Overview

```
   ┌────────┐       open conversation
   │ Mobile │────────────────────────▶ POST /messages/:id/seen
   └────────┘                                  │
                                               ▼
                              ┌────────────────────────────┐
                              │  Messaging service         │
                              │  resolveReceiptVisibility  │
                              │   (sender, receiver,       │
                              │    scope)                  │
                              └─────┬──────────────────────┘
                                    │
                  ┌─────────────────┼──────────────────┐
                  ▼                 ▼                  ▼
        ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
        │ user_settings  │ │ user_friend_   │ │ user_server_   │
        │ .receipts_     │ │ overrides      │ │ overrides      │
        │  default       │ │                │ │                │
        └────────────────┘ └────────────────┘ └────────────────┘
                                    │
                  reciprocity check (both sides willing)
                                    │
                                    ▼
                              ┌─────────────┐
                              │ Centrifugo  │
                              │ message.    │
                              │ seen        │
                              └─────────────┘
```

## 2. Components

### Backend (Go)
- **Service patch:** `internal/services/messaging/receipts.go` (new) — resolver `ShouldShowSeen(senderID, viewerID, scope)`.
- **Handler patch:** `internal/handlers/messages_handler.go` — receipt endpoint.
- **Models:** add `ReadReceiptSettings` to `user_settings`.

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/privacy/read_receipts_control/`
  - `domain/`: `ReceiptScope`, `ReceiptPolicy`.
  - `application/`: `receiptSettingsProvider`.
  - `presentation/`: `ReceiptToggleTile`, `FriendReceiptOverrideSheet`, `ServerReceiptOverrideSheet`.
- Patch DM settings, friend profile, server settings to embed `ReceiptToggleTile`.

### Infra
- DB: extend `user_settings`; new override tables.
- Cache: Redis `receipts:matrix:<user_id>` 5min TTL (resolved policy snapshot).

## 3. API Contracts

### REST
```
PATCH  /api/v1/users/me/settings/receipts        global default
PATCH  /api/v1/dms/:id/receipts                  per-DM
PATCH  /api/v1/friends/:friend_id/receipts       per-friend
PATCH  /api/v1/servers/:id/receipts              per-server
POST   /api/v1/messages/:id/seen                 mark seen (existing endpoint, augmented)
```

### WebSocket / Centrifugo
- Existing channel; `message.seen` event publishes only when reciprocity holds.

### Payloads
```jsonc
// PATCH receipts
{ "send_receipts": true, "see_receipts": true }

// effective resolution example
{ "scope": "dm:abc123", "send": true, "see": true, "reciprocal": true }
```

## 4. Permissions & Auth

- All toggles per-user; user can only modify their own.
- RLS on override tables: `user_id = auth.uid()`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Resolver latency | <2 ms |
| Cache hit ratio | ≥95% |
| Storage | small |

## 6. Dependencies

- Existing `user_settings` table.
- Existing messaging service.

## 7. Observability

- Metrics: `flicko_receipts_resolutions_total{result}`, `flicko_receipts_overrides_total{scope_type}`.
- Logs: nothing privacy-sensitive.
- Traces: span on resolver.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Cache stale | one user sees outdated state for ≤5 min | acceptable; cache invalidation on toggle |
| Resolver bug | leaks receipts contrary to user intent | unit tests at every override layer |
| Reciprocity computed wrong | one-sided receipts | property-based tests in CI |

## 9. Threat Model

**Attackers**
- A1: Stalker correlating "last seen" times. Mitigation: receipts off by default; reciprocity prevents one-sided observation.
- A2: Workplace community admin tracking off-hours engagement. Mitigation: per-server override; default-off.

**Assets**
- Read state per message. Already exists; this feature controls who can observe it.

**Limitations (in user-facing copy)**
- "Last online" presence is a separate setting not covered by this feature; controlled in privacy settings.
