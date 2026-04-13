# WebSocket Gateway (`ws-gateway`)

> **Reading time:** ~12 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

The `ws-gateway` is Flicko's custom real-time edge. Designed to hold tens of thousands of simultaneous connections within a minimal memory footprint, it is the bridge between the backend event ecosystem and the mobile client.

---

## Architecture

The Gateway is purely a "dumb pipe".
- **Stateless:** It does not know if a message is a "ban" or a "new role".
- **No Database:** It never talks to PostgreSQL, therefore it cannot be bottlenecked by database connection pools.
- **Dependency:** Its only dependency is Upstash Redis.

```mermaid
graph LR
    C[📱 Mobile App] <-->|TCP WebSockets| WS[ws-gateway Hub]
    WS <-->|Commands| REDIS[🔴 Redis Pub/Sub]
```

---

## The Connection Lifecycle

The gateway uses the popular `github.com/gorilla/websocket` Go library.

### 1. Upgrade & Auth
When a mobile client connects to `WSS /api/v1/ws`, the HTTP connection is upgraded to a TCP socket. 
However, WebSockets do not support HTTP Headers (like `Authorization: Bearer`) across all client platforms seamlessly.

Instead, Flicko forces an **Identify Handshake**:
1. Connection upgrades. Server starts a 5-second deadline timer.
2. Client sends an `OpIdentify` JSON payload containing their JWT.
3. Gateway validates the JWT mathematically (using `config.JWTSecret`).
4. Support or fail: If invalid or timeout expires, the WebSocket `Close()` is called immediately.

### 2. The Hub and Subscriptions
Once authenticated, the user is registered in the central `Hub`.
The Gateway then queries an internal fast-cache to determine which Servers the user belongs to, and dynamically subscribes the user's socket to those specific Redis Channels (e.g., `server:123`, `dm:456`).

### 3. Ping/Pong Heartbeat
To keep restrictive NATs and firewalls from dropping the idle TCP connection, the Gateway relies on a strict heartbeat pulse.
- **Client:** Must send `OpHeartbeat` every 30 seconds.
- **Server:** Responds with `OpHeartbeatAck`.
- If a client misses 2 consecutive heartbeats, the server assumes a zombie connection and force-closes the socket.

---

## Redis Fanout Mechanism

The power of `ws-gateway` is how it distributes data.

```go
// Simplified Hub Subscription mapping
type Hub struct {
    sync.RWMutex
    // Maps a Redis Channel ID to a map of active WebSocket connections
    subscriptions map[string]map[*Connection]bool
}
```

When a `MESSAGE_CREATE` event payload arrives from Redis targeting `channel:abc`:
1. The Hub locks the `subscriptions` map with an `RLock`.
2. It retrieves the list of `*Connection` pointers subscribed to `channel:abc`.
3. It iterates over the pointers, writing the JSON payload directly to the socket buffer.

By utilizing a read-lock (`RLock`) during fanout, hundreds of goroutines can broadcast messages simultaneously without blocking each other.

---

## Handling Typing Indicators

Typing indicators generate massive volumes of high-frequency, low-value events.
If we sent typing indicators to PostgreSQL, the database would melt.

The `ws-gateway` handles typing indicators exclusively over Redis:
1. Client sends `{"op": "typing", "channel_id": "xyz"}` to Gateway.
2. Gateway instantly publishes `TYPING_START` to Redis `channel:xyz`.
3. Gateway fans it out to all other clients connected to `channel:xyz`.
4. The event is intentionally never saved to disk.

---

## Scaling the Gateway

Because the Gateway relies on Redis Pub/Sub as its backplane, scaling horizontally is trivial.

If `ws-gateway-1` is holding 10,000 connections and runs out of RAM, we simply spin up `ws-gateway-2`. Cloudflare/NGINX load balances the new incoming Websocket connections to node 2.
Because both nodes are subscribed to the exact same Redis cluster, a message sent by a user on Node 1 will hit Redis, bounce to Node 2, and be delivered to a recipient connected to Node 2 seamlessly.

---

## Related Documentation

- [Features: Real-Time Messaging](../features/real-time-messaging.md) — How the message reaches the Gateway
- [Backend: Overview](overview.md) — How the Gateway fits into the whole architecture

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
