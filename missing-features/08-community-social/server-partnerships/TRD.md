# Server Partnerships — Technical Requirements

## 1. Architecture Overview

```
+------------------+   POST /partnerships   +-----------------+
|  Mobile (Flutter)| --------------------->|  Go Backend     |
+------------------+                       |  partner_service|
                                           +--------+--------+
                                                    |
                  +--------------------+            v
                  |  Centrifugo        |   +-----------------+
                  |  partner:<server>  |   |  Postgres       |
                  +--------------------+   |  partnerships   |
                            ^              +--------+--------+
                            |                       |
                            |              partnerships_metrics
                            |                       |
                            +-----------------------+
                                    realtime updates
```

`partnerships` is bilateral, identified by `(server_a, server_b)` with `server_a < server_b` invariant. Status transitions handled in service layer with audit trail.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/server-partnerships/service.go`
- **Metrics:** `backend/internal/services/social/server-partnerships/metrics.go`
- **Handlers:** `backend/internal/handlers/social/partnerships_handler.go`
- **Models:** `backend/internal/models/social/partnership.go`
- **Repo:** `backend/internal/repo/social/partnership_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/server-partnerships/`
  - `data/`: dto, repo
  - `domain/`: partnership entity, status enum
  - `application/`: providers
  - `presentation/`: partners_list, propose_dialog, requests_inbox, analytics

### Infra
- DB: tables in migration 195
- Realtime: Centrifugo `partner:<server_id>`
- Cache: Redis for partner lists
- Tracker: invite click attribution stored in `partnership_referrals`

## 3. API Contracts

### REST
```
POST   /api/v1/servers/:id/partnerships                propose
GET    /api/v1/servers/:id/partnerships
GET    /api/v1/servers/:id/partnerships/inbox
POST   /api/v1/partnerships/:pid/accept
POST   /api/v1/partnerships/:pid/decline
DELETE /api/v1/partnerships/:pid                       terminate
GET    /api/v1/partnerships/:pid/metrics
```

### WebSocket / Centrifugo
- Channel: `partner:<server_id>`
- Events: `partnership.proposed`, `partnership.accepted`, `partnership.terminated`

### Payloads
```jsonc
{
  "id": "uuid",
  "server_a": "uuid",
  "server_b": "uuid",
  "status": "pending|active|declined|terminated",
  "proposer_id": "uuid",
  "message": "string",
  "invite_a_for_b": "code",
  "invite_b_for_a": "code",
  "created_at": "iso8601",
  "accepted_at": "iso8601|null",
  "terminated_at": "iso8601|null"
}
```

## 4. Permissions & Auth

- Propose, accept, decline, terminate require `MANAGE_SERVER`
- Read partner list public for public servers
- Analytics gated to `MANAGE_SERVER`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| List latency p50 | <80 ms |
| Throughput | low (admin-only) |
| Storage | trivial |

## 6. Dependencies

- `servers`, `invites`, `server_member_perms`
- Audit log

## 7. Observability

- Metrics: `flicko_partnerships_active`, `flicko_partnership_joins_total`
- Logs: structured per state transition
- Traces: OTel
- Dashboards: `social-partnerships`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Hostile owner change | partnership stale | re-acceptance prompt on owner change |
| Spam proposals | inbox flooded | rate limit 5 outbound/day per server |
| Invite revocation | broken slot | regenerate on detect |
