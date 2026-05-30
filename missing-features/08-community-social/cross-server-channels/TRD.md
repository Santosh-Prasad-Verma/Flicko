# Cross-Server Channels — Technical Requirements

## 1. Architecture Overview

```
+-----------+     +-----------+     +-----------+
| Server A  |     | Server B  |     | Server C  |
| #lounge   |     | #lounge   |     | #lounge   |
+-----+-----+     +-----+-----+     +-----+-----+
      \                |               /
       \               |              /
        v              v             v
       +---------------------------------+
       |   cross_server_links (link_id)  |
       +---------------+-----------------+
                       |
                       v
                +------+------+
                |  messages   |
                |  link_id    |
                +------+------+
                       |
                       v
                NATS flicko.link.<id>
                       |
                       v
              Centrifugo channel:link:<id>
                       |
                       v
              Mobile clients per server
```

A message in a linked channel writes once to `messages` with `link_id`. Each server's client subscribes to `channel:link:<id>` (in addition to per-channel) and receives the event. Local mod overlays are applied per server.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/cross-server-channels/service.go`
- **Permission intersector:** `backend/internal/services/social/cross-server-channels/perms.go`
- **Local mod overlay:** `backend/internal/services/social/cross-server-channels/mod_overlay.go`
- **Handlers:** `backend/internal/handlers/social/cross_server_handler.go`
- **Models:** `backend/internal/models/social/cross_server_link.go`
- **Repo:** `backend/internal/repo/social/cross_server_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/cross-server-channels/`
  - `data/`, `domain/`, `application/`, `presentation/`
  - Linked-channel badge, member-pop "via {server}" subtitle

### Infra
- DB: tables in migration 197
- Realtime: Centrifugo `channel:<channel_id>` plus `link:<id>` for cross-fanout
- Cache: Redis for link membership and perms
- Queue: NATS subjects `flicko.link.message.created`, `link.deleted`

## 3. API Contracts

### REST
```
POST   /api/v1/links                           propose link
POST   /api/v1/links/:id/join                  invite-accept
POST   /api/v1/links/:id/leave
POST   /api/v1/links/:id/dissolve
GET    /api/v1/channels/:id/link
GET    /api/v1/links/:id/members
PATCH  /api/v1/links/:id                       rename, pause
POST   /api/v1/messages/:mid/local-action      hide/warn/remove_locally
```

Existing `POST /api/v1/messages` learns to accept `link_id` resolved from channel.

### WebSocket / Centrifugo
- Channel: `link:<id>` and `channel:<channel_id>`
- Events: existing `message.created`, `message.deleted`, plus `link.member.joined`, `link.member.left`

### Payloads
```jsonc
{
  "id": "uuid",
  "name": "Region Mods Lounge",
  "status": "active",
  "members": [
    {"channel_id":"...","server_id":"...","status":"active"}
  ]
}
```

## 4. Permissions & Auth

- Create link requires `MANAGE_CHANNEL` on each side
- Join requires same
- Send message requires intersection of post permissions across all participating channels
- Local mod removal is per-server only
- Global delete (by author or global mod role) cascades

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Send latency p50 | <120 ms |
| Cross-server fanout p99 | <800 ms |
| Throughput per link | up to 200 msg/s |
| Storage savings | -40% vs duplication |

## 6. Dependencies

- Existing messaging, channels, perms model
- Centrifugo, NATS

## 7. Observability

- Metrics: `flicko_link_messages_total`, `flicko_link_fanout_seconds`, `flicko_link_perm_denials_total`
- Logs: structured per link event
- Traces: OTel
- Dashboards: `social-cross-server`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| One participating channel deleted | partial visibility | mark member status=removed, keep link |
| Permission divergence | unexpected denies | clear UI hint in compose |
| Split-brain on NATS | inconsistent fanout | at-least-once + dedup |
| Local mod abuse | visibility games | audit log surfaced to peer mods |
