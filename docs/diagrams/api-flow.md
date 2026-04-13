# API Request Flow Diagram

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## HTTP Request Lifecycle

This diagram shows the complete path of an API request from client to database and back.

```mermaid
sequenceDiagram
    participant C as 📱 Mobile Client
    participant CF as ☁️ Cloudflare
    participant N as 🔀 NGINX
    participant MW as 🛡️ Middleware Stack
    participant H as 📋 Handler
    participant S as ⚙️ Service
    participant DB as 🐘 PostgreSQL
    participant R as 🔴 Redis

    C->>CF: HTTPS POST /api/v1/messages<br/>Authorization: Bearer JWT

    Note over CF: Layer 0: DDoS + WAF Check

    CF->>N: Forward (Origin TLS)

    Note over N: Layer 1:<br/>Rate limit check (30 req/s)<br/>Body size check (25 MB)

    N->>MW: Forward to backend

    Note over MW: Middleware Stack (in order):<br/>1. Request ID (X-Request-ID)<br/>2. CORS headers<br/>3. 30s timeout context<br/>4. Body limit (10 MB)<br/>5. Input sanitization log<br/>6. CSRF token validation<br/>7. Sensitive header redaction<br/>8. Redis rate limit check<br/>9. JWT auth verification

    MW->>H: Authenticated request<br/>(userID in context)

    Note over H: Handler:<br/>1. Parse path params<br/>2. Validate input<br/>3. Extract userID

    H->>S: service.CreateMessage(ctx, input)

    Note over S: Service:<br/>1. Validate content (1-4000 chars)<br/>2. Sanitize HTML<br/>3. Check permissions

    S->>DB: INSERT INTO messages (...)
    DB-->>S: Message row

    S->>R: PUBLISH channel:{channelID}
    R-->>S: OK

    S-->>H: (*Message, nil)
    H-->>MW: 201 JSON response

    MW-->>N: Response
    N-->>CF: Response
    CF-->>C: 201 Created
```

## WebSocket Connection Flow

```mermaid
sequenceDiagram
    participant C as 📱 Mobile Client
    participant N as 🔀 NGINX
    participant WS as ⚡ ws-gateway
    participant R as 🔴 Redis
    participant DB as 🐘 PostgreSQL

    C->>N: GET /ws (Upgrade: websocket)<br/>Authorization: Bearer JWT

    Note over N: Rate limit: ws_limit (5 req/s)

    N->>WS: WebSocket Upgrade

    WS->>WS: Verify JWT
    WS->>WS: Create Connection object
    WS->>WS: Register in Hub
    WS->>R: SUBSCRIBE channel:* for user's servers

    WS-->>C: OpReady {session_id, heartbeat_interval}

    loop Heartbeat (every 30s)
        C->>WS: OpHeartbeat
        WS-->>C: OpHeartbeatAck
    end

    Note over R: Another user sends a message

    R->>WS: channel:{id} message payload
    WS->>WS: Look up subscribers for channel
    WS-->>C: OpDispatch {type: MESSAGE_CREATE, data: {...}}

    Note over C: User sends a message

    C->>WS: OpDispatch {type: MESSAGE_CREATE, data: {...}}
    WS->>WS: Rate limit check (10 msg/s)
    WS->>R: PUBLISH channel:{id}
    WS->>DB: Batch insert (via msg-service)
```
