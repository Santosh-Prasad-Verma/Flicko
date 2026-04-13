# Data Flow Architecture

> **Reading time:** ~20 minutes · **Audience:** All Developers · **Last Updated:** 2026-04-11

This document traces every major data flow through the Flicko system — from user action to database persistence to real-time delivery. Each flow shows the exact services, handlers, Redis channels, and database tables involved. Use this to understand how features work end-to-end and to debug issues at any point in the pipeline.

---

## Flow 1: User Sends a Message

This is the most common flow in Flicko, involving all three services.

```mermaid
sequenceDiagram
    participant App as 📱 Mobile App
    participant NGX as 🔀 NGINX
    participant MSG as 📨 msg-service
    participant DB as 🐘 PostgreSQL
    participant RD as 🔴 Redis
    participant WS as ⚡ ws-gateway
    participant BE as 🤖 backend
    participant App2 as 📱 Other Clients

    App->>NGX: POST /api/v1/channels/{channelId}/messages<br/>{content: "Hello!", attachments: []}
    Note over NGX: Rate limit check (api zone: 30 req/s)<br/>TLS termination, body size check (25 MB)
    NGX->>MSG: Forward to upstream msg-service:8081

    Note over MSG: 10-layer middleware pipeline
    MSG->>MSG: 1. Generate request ID (UUID v4)
    MSG->>MSG: 2. CORS headers
    MSG->>MSG: 3. 30s timeout context
    MSG->>MSG: 4. 10 MB body limit check
    MSG->>MSG: 5. HTML/XSS sanitize input
    MSG->>MSG: 6. CSRF token validate
    MSG->>MSG: 7. Redact sensitive headers
    MSG->>MSG: 8. Redis rate limit check
    MSG->>MSG: 9. JWT validate → extract user_id
    MSG->>MSG: 10. RBAC: check SEND_MESSAGES permission

    MSG->>MSG: Add message to batch buffer
    Note over MSG: Buffer reaches 50 msgs OR 50ms timer fires

    MSG->>DB: BULK INSERT INTO messages<br/>(id, channel_id, user_id, content, created_at)
    DB-->>MSG: Inserted rows returned

    MSG->>RD: PUBLISH channel:{channelId}<br/>{type: MESSAGE_CREATE, data: {message}}
    MSG-->>App: 201 Created {message object}

    RD-->>WS: Deliver to all subscribers of channel:{channelId}
    WS->>WS: Look up connections subscribed to this channel
    WS->>App2: WebSocket: OpDispatch<br/>{type: MESSAGE_CREATE, data: {message}}

    RD-->>BE: Deliver MESSAGE_CREATE event
    BE->>BE: Event Bus → AutoMod Bot
    BE->>BE: Run 8 content filters
    alt Message violates a filter
        BE->>DB: DELETE FROM messages WHERE id = msg.id
        BE->>DB: INSERT INTO warnings (user_id, reason, ...)
        BE->>RD: PUBLISH channel:{channelId}<br/>{type: MESSAGE_DELETE, data: {id}}
        RD-->>WS: Deliver deletion event
        WS->>App2: OpDispatch {type: MESSAGE_DELETE}
    end

    BE->>BE: Event Bus → Leveling Bot
    BE->>DB: UPDATE user_xp SET xp = xp + random(15,25)<br/>WHERE user_id = ... AND server_id = ...
```

**Key observations:**
- The message is persisted to PostgreSQL BEFORE it's delivered via WebSocket. This ensures no message loss even if ws-gateway crashes.
- AutoMod runs asynchronously — the sender gets a 201 response immediately. If AutoMod deletes the message, all clients receive a `MESSAGE_DELETE` event.
- The batcher groups up to 50 messages into a single INSERT, reducing database round-trips from ~50/sec to ~1/sec under load.

---

## Flow 2: User Joins a Voice Channel

```mermaid
sequenceDiagram
    participant App as 📱 Mobile App
    participant BE as 🤖 backend
    participant DB as 🐘 PostgreSQL
    participant RD as 🔴 Redis
    participant WS as ⚡ ws-gateway
    participant LK as 🎙️ LiveKit Cloud
    participant Others as 📱 Other Clients

    App->>BE: GET /api/v1/voice/token?channel_id={id}
    BE->>BE: Validate JWT, extract user_id
    BE->>DB: Check member has CONNECT permission for channel
    BE->>BE: Generate LiveKit room token (JWT)<br/>Room: channel_id, Identity: user_id

    BE->>DB: INSERT INTO voice_states<br/>(user_id, channel_id, session_id, self_mute, self_deaf)
    BE->>RD: PUBLISH channel:{channelId}<br/>{type: VOICE_STATE_UPDATE, data: {user joined}}

    BE-->>App: {token: "livekit_jwt_token"}

    App->>LK: Connect with token (WebRTC)
    LK-->>App: Media stream established (Opus audio)

    RD-->>WS: Deliver VOICE_STATE_UPDATE
    WS->>Others: OpDispatch {type: VOICE_STATE_UPDATE}
    Note over Others: Channel member list updates<br/>to show user in voice channel
```

---

## Flow 3: Direct Upload to Cloudinary

```mermaid
sequenceDiagram
    participant App as 📱 Mobile App
    participant BE as 🤖 backend
    participant CDN as ☁️ Cloudinary

    App->>BE: GET /api/v1/cloudinary/sign<br/>?folder=avatars&eager=w_200,h_200,c_fill
    BE->>BE: Validate JWT
    BE->>BE: Generate HMAC-SHA256 signature<br/>using CLOUDINARY_API_SECRET
    BE-->>App: {timestamp, signature, api_key, cloud_name}

    App->>CDN: POST https://api.cloudinary.com/v1_1/{cloud}/image/upload<br/>file: <binary>, timestamp, signature, api_key
    Note over App,CDN: Direct upload — no data through Flicko backend
    CDN-->>App: {secure_url: "https://res.cloudinary.com/...", public_id: "..."}

    App->>BE: PUT /api/v1/users/@me<br/>{avatar_url: "https://res.cloudinary.com/..."}
    BE->>BE: Validate URL, update user record
```

**Key design decision:** Media never passes through Flicko's backend servers. This prevents the Flicko VPS from being a bandwidth bottleneck and leverages Cloudinary's global CDN edge network. The backend only handles signature generation (~100 bytes of data per request).

---

## Flow 4: Friend Request Lifecycle

```mermaid
sequenceDiagram
    participant A as 📱 User A
    participant BE as 🤖 backend
    participant DB as 🐘 PostgreSQL
    participant RD as 🔴 Redis
    participant WS as ⚡ ws-gateway
    participant B as 📱 User B

    A->>BE: POST /api/v1/friends/request<br/>{target_user_id: "B"}
    BE->>DB: Check no existing friendship/block
    BE->>DB: INSERT INTO friends<br/>(user_id: A, friend_id: B, status: pending)
    BE->>RD: PUBLISH user:{B}<br/>{type: FRIEND_REQUEST, from: A}
    BE-->>A: 201 Created

    RD-->>WS: Deliver to User B's connection
    WS->>B: OpDispatch {type: FRIEND_REQUEST}

    Note over B: User B accepts the request

    B->>BE: PUT /api/v1/friends/{requestId}/accept
    BE->>DB: UPDATE friends SET status = 'accepted'
    BE->>RD: PUBLISH user:{A}<br/>{type: FRIEND_ACCEPTED, user: B}
    BE-->>B: 200 OK

    RD-->>WS: Deliver to User A's connection
    WS->>A: OpDispatch {type: FRIEND_ACCEPTED}
```

---

## Flow 5: Server Creation with Template

```mermaid
sequenceDiagram
    participant App as 📱 Mobile App
    participant BE as 🤖 backend
    participant DB as 🐘 PostgreSQL

    App->>BE: POST /api/v1/servers<br/>{name: "Gaming Hub", template: "gaming"}
    BE->>BE: Validate JWT, extract user_id

    Note over BE,DB: Transaction begins

    BE->>DB: INSERT INTO servers (name, owner_id)
    BE->>DB: INSERT INTO members (server_id, user_id)
    BE->>DB: INSERT INTO roles (@everyone role with default perms)
    BE->>DB: INSERT INTO member_roles (owner gets @everyone)

    Note over BE: Apply "gaming" template
    BE->>DB: INSERT channels: #general, #game-chat,<br/>#lfg, #screenshots, #voice-general, #voice-ranked
    BE->>DB: INSERT roles: Admin (all perms),<br/>Moderator, Member, Muted

    Note over BE,DB: Transaction commits

    BE-->>App: 201 Created {server with channels and roles}
```

---

## Flow 6: Bot Slash Command Execution

```mermaid
sequenceDiagram
    participant App as 📱 Mobile App
    participant MSG as 📨 msg-service
    participant RD as 🔴 Redis
    participant BE as 🤖 backend
    participant DB as 🐘 PostgreSQL
    participant WS as ⚡ ws-gateway

    App->>MSG: POST /api/v1/channels/{id}/messages<br/>{content: "/ban @user reason"}
    MSG->>DB: INSERT INTO messages
    MSG->>RD: PUBLISH channel:{id}

    RD-->>BE: MESSAGE_CREATE event
    BE->>BE: Command Router parses "/ban"
    BE->>BE: Match to ModerationBot.handleBan()
    BE->>BE: Check invoker has BAN_MEMBERS permission

    BE->>DB: INSERT INTO bans (server_id, user_id, reason, duration)
    BE->>DB: DELETE FROM members WHERE user_id = target
    BE->>DB: INSERT INTO audit_log (action: "ban", ...)
    BE->>DB: INSERT INTO warnings (user_id: target, type: "ban")

    BE->>RD: PUBLISH channel:{mod-log}<br/>{type: MESSAGE_CREATE, content: "🛡️ @user banned by @mod"}
    RD-->>WS: Deliver ban notification
    WS->>App: OpDispatch {type: MEMBER_REMOVE}
```

---

## Flow 7: Permission Calculation

When checking if a user can perform an action (e.g., send a message in a specific channel), the permission system follows this calculation:

```
Step 1: Collect user's roles in the server
    SELECT r.permissions FROM roles r
    JOIN member_roles mr ON mr.role_id = r.id
    JOIN members m ON m.id = mr.member_id
    WHERE m.user_id = :user_id AND m.server_id = :server_id

Step 2: Combine role permissions with bitwise OR
    base_permissions = role1.perms | role2.perms | role3.perms

Step 3: Check if server owner (bypass all checks)
    IF user_id == server.owner_id → GRANT ALL

Step 4: Apply channel overwrites
    FOR each overwrite WHERE channel_id = :channel_id:
        base_permissions &= ~overwrite.deny    -- Remove denied bits
        base_permissions |= overwrite.allow     -- Add allowed bits

Step 5: Check specific permission bit
    has_permission = (base_permissions & REQUIRED_PERMISSION) != 0
```

```mermaid
graph TD
    A[User requests action] --> B{Server owner?}
    B -->|Yes| C[✅ GRANT - bypass all checks]
    B -->|No| D[Collect user roles in server]
    D --> E[Bitwise OR all role permissions]
    E --> F{Channel-specific?}
    F -->|No| G[Check permission bit]
    F -->|Yes| H[Apply channel overwrites]
    H --> I[Remove DENY bits]
    I --> J[Add ALLOW bits]
    J --> G
    G -->|Bit set| K[✅ GRANT]
    G -->|Bit not set| L[❌ DENY - 403 Forbidden]
```

---

## Flow 8: WebSocket Connection Establishment

```mermaid
sequenceDiagram
    participant App as 📱 Mobile App
    participant NGX as 🔀 NGINX
    participant WS as ⚡ ws-gateway
    participant DB as 🐘 PostgreSQL
    participant RD as 🔴 Redis

    App->>NGX: GET /ws (Upgrade: websocket)
    Note over NGX: Rate limit: ws zone (5 conn/s)
    NGX->>WS: WebSocket Upgrade
    WS->>WS: Accept WebSocket connection
    WS->>WS: Start read goroutine
    WS->>WS: Start write goroutine

    App->>WS: OpIdentify {token: "eyJ..."}
    WS->>WS: Validate JWT (HMAC-SHA256)
    WS->>DB: SELECT server_id FROM members WHERE user_id = :uid
    WS->>DB: SELECT channel_id FROM channels WHERE server_id IN (...)
    WS->>RD: SUBSCRIBE channel:{c1}, channel:{c2}, ...channel:{cN}

    WS->>App: OpReady {heartbeat_interval: 30000, session_id: "..."}

    WS->>RD: PUBLISH presence:online {user_id, status: "online"}
    Note over WS,App: Connection established ✅
```

---

## Related Documentation

- [Architecture: System Overview](system-overview.md) — Service responsibilities and communication patterns
- [Architecture: Database Design](database-design.md) — Tables and relationships referenced in these flows
- [Security: Middleware Pipeline](../security/middleware-pipeline.md) — Detailed breakdown of the 10-layer pipeline shown in Flow 1
- [Features: Real-Time Messaging](../features/real-time-messaging.md) — User-facing feature documentation for messaging

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
