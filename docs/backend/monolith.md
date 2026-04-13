# The Backend Monolith

> **Reading time:** ~12 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

The main `backend` service is the central nervous system of Flicko. While `msg-service` specializes in throughput and `ws-gateway` in connections, the Monolith handles state, business rules, and the integration layer.

---

## Architecture Overview

The Monolith mounts to any route prefixed by `/api/v1/` that is not explicitly captured by NGINX for the other two microservices.

**Key responsibilities:**
- Resolving deep RBAC permissions checking.
- Issuing LiveKit WebRTC tokens.
- Generating Cloudinary upload signatures.
- Managing Stripe webhook state transitions.
- Processing the Bot framework and AutoMod logic.

---

## Dependency Injection

The Monolith utilizes strict Dependency Injection. To prevent globally coupled singletons (which break unit testing), dependencies are passed structurally downward.

```go
func main() {
    // 1. Init Connections
    db := database.NewSupabaseConnection(config.DBUrl)
    redisClient := redis.NewUpstashClient(config.RedisUrl)

    // 2. Init Core Services
    eventBus := events.NewBus(redisClient)
    
    // 3. Init Domain Services (Injection)
    serverSvc := services.NewServerService(db)
    userSvc := services.NewUserService(db)
    
    // 4. Init Handlers
    serverHandler := handlers.NewServerHandler(serverSvc)
    
    // 5. Mount Router
    r := chi.NewRouter()
    r.Post("/servers", serverHandler.Create)
}
```

This pattern ensures that `handlers.NewServerHandler` cannot accidentally issue a raw SQL command without going through the business logic layer (`serverSvc`), ensuring permissions and constraints are consistently applied.

---

## Event Reactivity

The Monolith operates in two distinct execution modes simultaneously:

### 1. HTTP Request Lifecycle (Synchronous)
Standard REST API mode. A request enters the `chi` router, passes through the [Middleware Pipeline](../security/middleware.md), hits the Handler, runs Business Logic, and returns JSON. Execution blocks until completion.

### 2. Event Bus Worker Pool (Asynchronous)
While serving HTTP traffic, the Monolith also acts as a generic Redis Pub/Sub consumer.

```mermaid
graph TD
    REDIS[🔴 Redis (MsgService)] -->|Event| MONO[⚙️ Monolith Worker]
    MONO -->|Filter| BOTS[🤖 Active Bots]
    BOTS -->|auto-ban| DB[🐘 Postgres DB]
```

When `msg-service` successfully accepts a message, it publishes `MESSAGE_CREATE`. The Monolith's internal `events.Bus` intercepts this from Upstash, unmarshals it into a Go struct, and pushes it onto an internal channel. 

Workers pull from this channel and check if any internal systems demand reaction (e.g., The AutoMod Bot scanning the message text, or the Leveling Bot calculating XP).

---

## Webhook Handling

External platforms (Stripe, LiveKit) require a secure destination to post events. The Monolith serves as the sole receiver of external webhooks.

Routes under `/api/v1/webhooks/*` bypass the standard JWT JWT verification middleware. Instead, each individual handler is injected with a domain-specific middleware that calculates cryptographic payload signatures.

For example, `stripe_webhook.go` receives the raw raw HTTP body (before JSON decoding), grabs the `Stripe-Signature` header, computes HMAC SHA-256 against `STRIPE_WEBHOOK_SECRET`, and immediately aborts with 401 if compromised.

---

## Related Documentation

- [Backend: Database Layer](database-layer.md) — How the Monolith actually talks to PostgreSQL.
- [Features: Bot System](../features/bot-system.md) — How the Bot Engine hooks into the async Worker Pool.

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
