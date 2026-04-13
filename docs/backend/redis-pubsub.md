# Redis & Pub/Sub Architecture

> **Reading time:** ~7 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

Flicko relies on Upstash Redis as its high-speed nervous system. Because the application logic is split across three isolated microservices, Redis serves as the sole shared memory layer allowing them to communicate.

---

## 1. Event Propagation (Pub/Sub)

The primary use case of Redis in Flicko is standard Publish/Subscribe routing.

### Naming Convention
A payload is never published generically. It is always routed to a specific subset of users using predictable Topic namespaces.

- `channel:{uuid}` — Delivers to users viewing a specific server text/voice channel.
- `dm:{uuid}` — Delivers to users in a specific 1-on-1 or group DM.
- `user:{uuid}` — Delivers a targeted payload to a single user regardless of their current screen (used for Friend requests, System alerts).

### The Payload Structure

Every publish contains a `type` for the frontend/gateway router, and a `data` interface.
```go
type InternalPayload struct {
    Type string `json:"type"` // e.g., "MEMBER_JOIN", "MESSAGE_CREATE"
    Data any    `json:"data"` // Usually maps to a PostgreSQL struct
}
```

### The `go-redis` Implementation

```go
func PublishEvent(ctx context.Context, topic string, eventType string, data any) {
    payload := InternalPayload{Type: eventType, Data: data}
    bytes, _ := json.Marshal(payload)
    
    // Fire and forget - don't block the HTTP request
    go redisClient.Publish(ctx, topic, bytes)
}
```

---

## 2. Fast Caching

While the `backend` generally queries PostgreSQL directly, some data changes so frequently that Disk I/O would be a bottleneck. Redis provides fast distributed memory for these values.

**Examples:**
- **Rate Limit Counters:** We use the `INCR` and `EXPIRE` commands atomically to enforce distributed sliding-window rate limits across NGINX containers.
- **AutoMod Flood Detection:** We store the last 5 messages sent by a user in an ephemeral Redis List to run Levenshtein text-similarity comparisons to catch fast spammers.

---

## 3. The Dead Letter Queue (DLQ)

As documented in the [Message Service](msg-service.md) notes, if the database connection drops unexpectedly, we don't want users losing the messages they typed.

Since the `msg-service` possesses the message struct, it pushes the dropped message onto a Redis linked list using `RPUSH app:dlq:messages`. 

When PostgreSQL comes back online, a backend background worker performs an `LPOP` off the list and silently inserts the lost message.

---

## 4. Presence Keyspace Notifications

We utilize a special Redis configuration called **Keyspace Notifications** (`notify-keyspace-events "Ex"`). This allows Redis to emit a Pub/Sub message whenever a Key *expires*.

When a user connects, the Gateway sets:
`SET user:123:presence online EX 45`

If the gateway crashes, or the mobile user enters an elevator and loses internet without sending a clean logout packet, 45 seconds later Redis automatically expires the key. Because of Keyspace Notifications, Redis emits `__keyevent@0__:expired user:123:presence`. The `backend` receives this notification and routes an "offline" event instantly.

---

## Secure Connection

Because our Redis provider (Upstash) is hosted outside our data center, traffic must be encrypted. The `GoRedis` client is configured to connect using the `rediss://` scheme (Note the 's') which enforces TLS/SSL termination to prevent packet sniffing.
