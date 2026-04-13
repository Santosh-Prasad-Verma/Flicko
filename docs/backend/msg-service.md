# Message Service (`msg-service`)

> **Reading time:** ~10 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

The `msg-service` is a micro-API dedicated to one job: reliably processing incredibly high volumes of incoming text messages, writing them to disk efficiently, and publishing them for real-time delivery.

---

## Core Responsibilities

The `msg-service` mounts only endpoints starting with `/api/v1/channels/{channel_id}/messages`.

While the [Backend Monolith](monolith.md) handles complex business logic (payments, server creation, role mutation), the `msg-service` is heavily optimized for speed.

**The Pipeline of a Message:**
1. **Validation:** Checks body structure, string length, attachment URLs.
2. **Auth & RBAC:** Verifies the JWT and queries exact Server permissions to ensure the sender has `SEND_MESSAGES` in this channel.
3. **Queueing (The Batcher):** Places the message in a memory queue instead of querying PostgreSQL directly.
4. **Publishing:** Instantly emits the message to Upstash Redis for the `ws-gateway`.

---

## The Batch Insertion Engine

The main bottleneck during high traffic (e.g., an announcement in a 50k member server causing 200 users to reply simultaneously) is PostgreSQL connection transaction overhead. 

If we executed 200 separate `INSERT INTO messages` statements, even the Supavisor connection pooler would struggle.

**The Solution:** The `BatchInsertionEngine`

```go
type BatchEngine struct {
    messageChan chan *models.Message
    batchSize   int
    interval    time.Duration
}

func (b *BatchEngine) Start(ctx context.Context) {
    var buffer []*models.Message
    ticker := time.NewTicker(b.interval) // e.g. 50ms

    for {
        select {
        case msg := <-b.messageChan:
            buffer = append(buffer, msg)
            if len(buffer) >= b.batchSize {
                b.flush(buffer)
                buffer = nil
            }
        case <-ticker.C:
            if len(buffer) > 0 {
                b.flush(buffer)
                buffer = nil
            }
        case <-ctx.Done():
            if len(buffer) > 0 {
                b.flush(buffer) // Final flush on shutdown
            }
            return
        }
    }
}
```

### Flush Mechanics
When `flush()` runs, it utilizes PostgreSQL's `copyFrom` or extended `INSERT` format to insert 50 rows in a single 10ms transaction curve.

### Dead Letter Queue (DLQ)
What if `flush()` fails because PostgreSQL is momentarily rebooting?
The engine catches the `err`, and writes the dropped batch of 50 messages to a Redis List using `RPUSH msg_dlq`. 
Because the messages were already published to `ws-gateway` in step 4 of the pipeline, clients *see* the message immediately. Five minutes later, a background worker consumes the DLQ and quietly inserts them into postgres so they are retained in history requests.

---

## Generating Snowflakes (UUIDs)

Flicko relies entirely on Postgres UUIDv4 identifiers. Normally, giving the database `id = gen_random_uuid()` forces the DB to compute the UUID upon insertion.

Because `msg-service` defers database insertion via the Batch Engine, it must generate the UUIDs *in application space* using the `google/uuid` Go package. 
It creates the UUID, assigns it to the struct, publishes the complete object to Redis, and then hands the pre-ID'd struct to the Batch Engine.

---

## Thread Independence

The `msg-service` is deliberately decoupled from the Bot Engine (which runs inside the main Monolith).
When a user types `/ban @user`, the message hits the `msg-service`. The service does not process the command. It simply persists it, and publishes a `COMMAND_CREATE` internal event to Redis. The Monolith's Bot Router picks up that packet and acts upon it.

This ensures that a buggy slash command or slow bot response never degrades raw messaging latency.

---

## Related Documentation

- [Features: Real-Time Messaging](../features/real-time-messaging.md) — How the batcher benefits mobile clients
- [Backend: WebSocket Gateway](ws-gateway.md) — Who receives the published payloads

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
