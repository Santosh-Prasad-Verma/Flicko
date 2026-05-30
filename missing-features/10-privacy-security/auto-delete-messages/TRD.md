# Auto-Delete Messages — Technical Requirements

## 1. Architecture Overview

```
   ┌────────┐   set TTL on channel   ┌─────────────────┐
   │ Mod UI │───────────────────────▶│  Channel Auto-  │
   └────────┘                        │  Delete Service │
                                     └────────┬────────┘
                                              │ insert/update
                                              ▼
                              ┌──────────────────────────┐
                              │ channel_auto_delete_     │
                              │ settings (channel_id,    │
                              │ ttl_seconds, exempt_pin) │
                              └──────────────────────────┘
                                              │
                  pg_cron every 60s           │
                              ┌───────────────┘
                              ▼
   ┌──────────────────────────────────────────────────┐
   │ sweep_auto_delete_messages():                    │
   │   for each channel with TTL:                     │
   │     DELETE messages older than now() - ttl       │
   │     respecting pinned/system exemptions          │
   └──────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
    ┌────────────┐    ┌──────────────┐  ┌──────────────┐
    │ Centrifugo │    │ Search       │  │ Attachment   │
    │ message.   │    │ index sweeper│  │ sweeper      │
    │ deleted    │    │              │  │ (Appwrite)   │
    └────────────┘    └──────────────┘  └──────────────┘
```

## 2. Components

### Backend (Go) — extends `disappearing_messages` sweeper

- **Service:** `internal/services/privacy/auto_delete_messages/service.go`
- **Worker (shared):** sweep function called from existing `disappearing_messages` cron path, with a separate SQL function `sweep_auto_delete_messages()`.
- **Handler:** `internal/handlers/auto_delete_handler.go` — set/update channel TTL.
- **Models:** `internal/models/channel_auto_delete.go`.

### Mobile (Flutter)

- **Feature folder:** `mobile/lib/features/privacy/auto_delete_messages/`
  - `application/`: `channelTtlProvider`.
  - `presentation/`: `AutoDeleteSettingsSheet` (mod), `AutoDeleteBadge`, `ComposerAutoDeleteHint`.
- Patch channel header to render badge when TTL > 0.

### Infra
- DB: `channel_auto_delete_settings`.
- pg_cron: same minute-tick as disappearing-messages, separate function.
- Realtime: Centrifugo `message.deleted` reused.

## 3. API Contracts

### REST
```
PATCH /api/v1/channels/:id/auto-delete  { ttl_seconds, exempt_pinned, exempt_system }
GET   /api/v1/channels/:id/auto-delete  → current setting
```

### WebSocket / Centrifugo
- Existing channel; `auto_delete.config_changed` event when mod toggles; `message.deleted` with reason `"auto_delete"`.

### Payloads
```jsonc
// PATCH
{
  "ttl_seconds": 86400,
  "exempt_pinned": true,
  "exempt_system": true
}
```

## 4. Permissions & Auth

- Only channel mods (`role_flags & MOD`) can change TTL.
- Setting is server-wide-visible.
- Audit-log entry on every change.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Sweep lag | <90s p99 |
| Sweep batch | up to 5k msgs / channel / minute |
| Per-channel concurrency | per-channel mutex via `FOR UPDATE SKIP LOCKED` |
| Setting change propagation | <2s realtime |

## 6. Dependencies

- Existing `disappearing_messages` sweeper (we share infra).
- pg_cron.
- Centrifugo message.deleted publisher.

## 7. Observability

- Metrics: `flicko_auto_delete_swept_total{channel_id}`, `flicko_auto_delete_lag_seconds`, `flicko_auto_delete_settings_changes_total`.
- Logs: counts only, no content.
- Traces: per-run span on sweeper.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Sweep stalls | content past TTL persists | health-check; alert at 5min lag |
| Bug deletes pinned | retention violation | strict WHERE on pin status; integration tests |
| Race with new posts | rare extra-old row | SKIP LOCKED |
| Mod accidental setting | loss of important content | confirmation dialog; audit log; soft-revert window? (v1: no) |

## 9. Threat Model

**Attackers**
- A1: Member who wants to evade mod retention. Mitigation: posts disappear; no opt-out.
- A2: Mod who weaponizes auto-delete to suppress evidence. Mitigation: audit log of TTL changes; server owner can revoke; community visible badge.
- A3: Adversary scraping channel before sweep. Mitigation: this is not a privacy mechanism vs scrapers; it is a retention/UX mechanism. Documented.

**Assets**
- Channel message history.

**Limitations (in user-facing copy)**
- This is a hygiene feature, not a privacy guarantee. Sender-side ephemerality (`disappearing-messages`) remains the per-message option.
