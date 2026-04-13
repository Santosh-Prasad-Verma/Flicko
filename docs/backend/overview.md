# Backend Overview

> **Reading time:** ~7 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

Flicko's backend infrastructure is built in highly concurrent, idiomatic Go. While the system appears as a single unified API to the mobile client, it is actually composed of three distinct microservices interacting over Redis Pub/Sub.

---

## 🏗️ 3-Service Architecture

We break the monolithic structure down only where performance dictates. 

### Why split into 3 services?
A traditional Node.js/Express monolith struggles when mixing long-lived connections (WebSockets) with heavy CPU REST workloads (JSON deserialization, image signature hashing). 
By splitting them in Go, we scale the `ws-gateway` (which holds thousands of idle TCP connections in RAM) independently from the `msg-service` (which scales horizontally based on CPU load from chat spikes).

1. [**The Main Monolith (`backend`)**](monolith.md)
   Handles all "cold" REST operations: user fetching, server creation, role permission management, Stripe webhooks, and the Bot Engine. It is the fattest service.
   
2. [**The WebSockets Gateway (`ws-gateway`)**](ws-gateway.md)
   A stateless proxy that maintains active secure TCP connections to clients. It listens to Redis for events and fans them out to connected sockets. It does not speak to PostgreSQL.
   
3. [**The Message Service (`msg-service`)**](msg-service.md)
   A specialized, high-throughput REST API that exclusively handles the `POST /messages` route. It contains the Batch Insertion Engine for database writes and acts as the main publisher to Redis.

---

## 📡 NGINX Request Routing

The React Native app only knows one base URL: `https://api.flicko.app`. NGINX acts as the reverse proxy, intelligently stripping path prefixes and routing traffic to the correct underlying Docker container:

```nginx
# Map WebSocket upgrade requests to ws-gateway
location /api/v1/ws {
    proxy_pass http://ws-gateway:8081;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
}

# Map high-throughput message routes to msg-service
location /api/v1/channels/([^/]+)/messages {
    proxy_pass http://msg-service:8082;
}

# Map everything else to the monolith
location /api/v1/ {
    proxy_pass http://backend:8080;
}
```

---

## 📦 Go Code Organization

All three backend services reside in a common monorepo structure.

```text
Flicko/
└── backend/
    ├── cmd/                  # Entry points
    │   ├── api/              # Monolith binary
    │   ├── msg-service/      # Msg Service binary
    │   └── ws-gateway/       # WS Gateway binary
    ├── internal/             # Private application code
    │   ├── bots/             # Bot Engine
    │   ├── config/           # Viper configuration loader
    │   ├── database/         # PostgreSQL utilities
    │   ├── events/           # Event Bus structs
    │   ├── handlers/         # Controllers/REST Endpoints
    │   ├── middleware/       # The 10-layer defense pipeline
    │   ├── models/           # Domain/Database Structs
    │   ├── redis/            # Pub/Sub abstractions
    │   └── services/         # Core business logic
    └── pkg/                  # Public/Shared libraries
```

---

## 🛠️ Concurrency Safety

Go makes it radically simple to spawn goroutines via `go doWork()`. However, we strictly follow structured concurrency patterns to avoid memory leaks:

1. **WaitGroups:** All background workers (like the Batch Insertion Engine) exist within a `sync.WaitGroup` to ensure clean shutdowns when Kubernetes sends a `SIGTERM`.
2. **Context Cancellation:** Every API request passes `r.Context()` deeply into database and Redis queries. If a mobile user closes the app mid-request, the context is cancelled, instantly aborting the PostgreSQL query to save resources.
3. **Mutexes:** In-memory maps (such as the `ws-gateway` connection tracker) use `sync.RWMutex` to prevent concurrent map writes, prioritizing Read locks for fast WebSocket fanout.

---

## Navigation

Proceed to explore the individual services in depth:
- [WebSocket Gateway Deep Dive](ws-gateway.md)
- [Message Service & Batcher](msg-service.md)
- [Backend Monolith](monolith.md)
