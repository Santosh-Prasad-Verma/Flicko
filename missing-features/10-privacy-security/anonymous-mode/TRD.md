# Anonymous Mode — Technical Requirements

## 1. Architecture Overview

```
                 join-as-anon flow
   ┌────────┐    ┌─────────────────┐    ┌──────────────┐
   │ Mobile │───▶│  AnonHandle     │───▶│  hmac(srv,   │
   │ Flutter│    │  Service (Go)   │    │  user)→hash  │
   └────────┘    └────────┬────────┘    └──────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  server_anon_   │
                 │  members table  │
                 └────────┬────────┘
                          │
   ┌──────────┐           ▼            ┌──────────┐
   │  Mod UI  │◀──── anon_handle ────▶│ audit_log │
   │ (anon-   │      (hash visible)   │  HMAC only│
   │  view)   │                        └──────────┘
   └──────────┘
```

Two identity surfaces: the *visible handle* (what other members and mods see) and the *internal hash* (what mod actions key off). The user_id is never exposed in anon-scoped queries.

## 2. Components

### Backend (Go) — extends `services/e2ee/`

- **Service:** `internal/services/privacy/anonymous_mode/service.go`
- **Handler:** `internal/handlers/anon_handle_handler.go`
- **Models:** `internal/models/anon_handle.go`
- **Repo:** `internal/repo/anon_handle_repo.go`
- **HMAC helper:** `internal/services/privacy/anonymous_mode/hash.go`
- **Handle generator:** `internal/services/privacy/anonymous_mode/handle_gen.go`

The HMAC key lives in HashiCorp Vault under `kv/privacy/anon_mode_hmac`. Rotated yearly with overlap; old key kept for ban-list back-resolution.

### Mobile (Flutter) — extends `features/e2ee/`

- **Feature folder:** `mobile/lib/features/privacy/anonymous_mode/`
  - `data/`: `anon_handle_repository.dart`, `anon_handle_dto.dart`, `anon_handle_remote_datasource.dart`
  - `domain/`: `anon_member.dart`, `join_anonymously_usecase.dart`, `reveal_identity_usecase.dart`
  - `application/`: `anon_join_provider.dart`, `anon_member_list_provider.dart`
  - `presentation/`: `anon_join_sheet.dart`, `anon_member_card.dart`, `reveal_identity_dialog.dart`

### Infra
- DB: Supabase Postgres — new tables `server_anon_members`, `server_anon_settings` (see `SCHEMA.md`).
- Realtime: Centrifugo channel `anon:server:<server_id>` for live member-list scrub.
- Cache: Redis keys `anon:handle:<server_id>:<handle>` (TTL 24h) for uniqueness lookups.
- Storage: none (no file uploads in v1).
- Search: anonymous members are *excluded* from Meilisearch user index.
- Queue: NATS subject `flicko.privacy.anon_mode.*` for async audit-log writes.

## 3. API Contracts

### REST
```
POST   /api/v1/servers/:server_id/anon/join     join anonymously
POST   /api/v1/servers/:server_id/anon/reveal   reveal real identity (irreversible)
GET    /api/v1/servers/:server_id/anon/members  list anon members (mods only)
PATCH  /api/v1/servers/:server_id/anon/settings toggle anon-allowed (owner)
```

### WebSocket / Centrifugo
- Channel: `anon:server:<server_id>`
- Events: `anon.member.joined` (anon_handle only), `anon.member.left`, `anon.member.revealed`

### Payloads
```jsonc
// POST /api/v1/servers/:id/anon/join
// req: empty body — server_id from path, user from auth
// 201 response
{
  "anon_handle": "QuietFox4218",
  "anon_avatar_url": "https://cdn.flicko.io/anon/quietfox4218.png",
  "joined_at": "2026-05-29T12:00:00Z"
}

// GET /anon/members (mod view)
{
  "members": [
    {
      "anon_handle": "QuietFox4218",
      "internal_hash": "h_3f8a2c...",  // for ban lookup
      "joined_at": "...",
      "warnings": 0,
      "messages_30d": 42
    }
  ]
}
```

## 4. Permissions & Auth

- **Required scopes:** `servers.anon.join` (member), `servers.anon.moderate` (mod), `servers.anon.configure` (owner).
- **Role checks:**
  - Owner: toggle anon-allowed on server.
  - Mod: list anon members, ban via internal hash, see anon_handle but not user_id.
  - Member: join anon if server allows + account is ≥14d old + email-verified.
- **RLS:** strict — `server_anon_members.user_id` only readable by `current_user_is_user_id()`. Mods read via security-definer function `mod_anon_view(server_id)` which strips user_id.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency (join-anon) | <150 ms |
| p99 latency | <600 ms |
| Throughput | 200 rps |
| Availability | 99.95% |
| Storage cost | <$0.0001 per anon member/month |
| HMAC compute | <2 ms per join |
| GDPR delete | full cascade on user soft-delete; HMAC mapping retained 30d for ban integrity then purged |

## 6. Dependencies

- Existing services: `services/e2ee/key_manager.go` (Vault client reused), `services/audit_log`, `services/server_membership`.
- New libs: none — `crypto/hmac` and `crypto/sha256` from stdlib.
- External APIs: none.

## 7. Observability

- Metrics: `flicko_anon_joins_total{server_id}`, `flicko_anon_reveals_total`, `flicko_anon_ban_evasion_attempts_total`, `flicko_anon_handle_collisions_total`.
- Logs: structured JSON. **Critical:** never log `user_id` and `anon_handle` together — that defeats the feature. Two log streams: identity-stream (auth-only) and anon-stream (no user_id).
- Traces: OTel spans wrap join-anon and reveal-identity. user_id stripped from anon-stream traces.
- Dashboards: Grafana board `anonymous_mode` — joins, reveals, bans, evasion attempts.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| HMAC key in Vault unavailable | join-anon disabled | Fall back to cached key (15m), then 503 with retry |
| Handle generator collides | join slow | Retry with new seed up to 5x, then 4-digit → 6-digit |
| user_id leaked into anon log | privacy breach | Pre-commit hook + log-redactor sidecar greps for `user_id` in `anon_*` log streams |
| Ban hash desync (old key) | bans bypass | Keep last 2 HMAC keys; check both on join |

## 9. Threat Model

**Attackers**
- A1: Curious member. Wants to dox `QuietFox4218`. Mitigation: no API endpoint returns user_id for an anon handle to non-self callers; client never receives it.
- A2: Malicious mod. Has DB read on mod-view. Mitigation: mod view is a security-definer function that returns hash + handle only; raw `server_anon_members` blocked by RLS.
- A3: Banned troll. Wants to rejoin under a new handle. Mitigation: HMAC of `(server_id, user_id)` is stable; ban list keys on hash; new handle hits same hash.
- A4: External adversary with stolen DB dump. Wants to map handles to users. Mitigation: HMAC key is in Vault, not in DB; without the key the dump is not reversible.
- A5: Subpoena. Mitigation: documented disclosure policy; we *can* resolve handle → user when legally compelled, and we say so.

**Assets**
- HMAC key (Vault, sealed at rest, rotated yearly).
- `server_anon_members.user_id` column (RLS-locked, encrypted at rest via Supabase pgsodium).
- Audit log entries (anon-stream contains only hash, never user_id).

**Out of scope**
- Network-level anonymity (IP). Use `vpn-detection` to *warn*; we do not run a Tor exit.
- Side-channel deanonymization via writing style. v1 ships a "stylometric warning" in the docs only.
