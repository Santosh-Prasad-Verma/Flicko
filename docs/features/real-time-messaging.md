# Real-Time Messaging

> **Reading time:** ~20 minutes · **Audience:** Backend, Mobile Developers · **Last Updated:** 2026-04-11

Real-time messaging is the core functionality of Flicko. This document details how messages are transmitted, stored, extended (threads/reactions), and delivered to thousands of users simultaneously.

---

## Table of Contents

- [Core Message Model](#core-message-model)
- [The Write Path: Batch Insertion](#the-write-path-batch-insertion)
- [The Read Path: WebSocket Delivery](#the-read-path-websocket-delivery)
- [Typing Indicators](#typing-indicators)
- [Reactions & Threads](#reactions--threads)
- [Message Editing & Deletion](#message-editing--deletion)
- [Full-Text Search](#full-text-search)

---

## Core Message Model

A message in Flicko is more than just text. The `messages` table in PostgreSQL stores rich metadata.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "channel_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "user_id": "db3a2b10-67cc-44a1-b847-19fc2ef3a774",
  "content": "Check out this design! @tarun",
  "reply_to_id": null,
  "thread_id": null,
  "pinned": false,
  "attachments": [
    {"url": "https://res.cloudinary.com/...", "type": "image/png"}
  ],
  "edited_at": null,
  "deleted_at": null,
  "created_at": "2026-04-11T12:00:00Z",
  "user": {
    "username": "alex",
    "avatar_url": "..."
  }
}
```

---

## The Write Path: Batch Insertion

When a mobile client sends a message, it makes a standard HTTP POST request to `msg-service`.

**Why HTTP and not WebSockets?**
While reading is done via WebSockets, *writing* is done via HTTP POST. This allows us to leverage standard HTTP infrastructure:
- Cloudflare WAF for payload inspection
- NGINX for body size limits (preventing giant payload DOS)
- Standard REST API status codes (400, 401, 403, 429)

### The Batcher

To handle high volumes, `msg-service` uses a custom Batch Insertion Engine. Instead of executing 100 `INSERT` statements per second, it queues them in memory and runs a bulk insert.

**Trigger Conditions:**
1. **Size:** 50 messages in the queue (Default max batch size).
2. **Time:** 50 milliseconds have elapsed since the first message in the queue.

*Failure handling:* If the bulk insert fails (e.g., database restart), the batch is dumped onto a Redis Dead Letter Queue (DLQ). A background worker attempts to replay the DLQ every 5 minutes. In the meantime, the messages are already in Redis Pub/Sub, so clients still saw them instantly.

---

## The Read Path: WebSocket Delivery

Once the message is buffered for database insertion, `msg-service` immediately publishes it to Redis.

**Channel Naming:** `channel:{channel_id}`

```go
// Inside msg-service
redis.Publish(ctx, "channel:"+msg.ChannelID, map[string]any{
    "type": "MESSAGE_CREATE",
    "data": msg,
})
```

### The `ws-gateway`

The `ws-gateway` service runs a central `Hub`. When a client connects via WebSocket, the Hub checks which servers they belong to, and subscribes to the Redis channels for every text channel in those servers.

When Redis receives the `PUBLISH` from `msg-service`, the `ws-gateway` receives it, looks up all WebSocket connections subscribed to `channel:{channel_id}`, and pushes the JSON payload down the TCP socket.

**Optimistic Deduplication:**
Because the sender also has an active WebSocket connection, they will receive the `MESSAGE_CREATE` event for their own message. The mobile app's Riverpod store compares the incoming message's `id` against its optimistic local buffer; if it matches, it ignores the WebSocket payload to prevent UI flickering.

---

## Typing Indicators

Typing indicators (`User is typing...`) are strictly ephemeral. They never touch the PostgreSQL database.

**Flow:**
1. Client types a keystroke.
2. Client checks if it has sent a typing event in the last 3 seconds. If no, it sends an `OpTyping` WebSocket frame to `ws-gateway`.
3. `ws-gateway` receives it and immediately publishes to Redis: `PUBLISH channel:{id} {"type":"TYPING_START", "user_id":"..."}`
4. `ws-gateway` broadcasts it to all other clients in the channel.
5. Mobile app receives `TYPING_START`, adds user to local state, and starts a 5-second JS timer. If no new `TYPING_START` is received before the timer fires, the user is removed from the typing list.

---

## Reactions & Threads

### Reactions
Reactions are stored in the `reactions` table.
```sql
CREATE TABLE reactions (
  id UUID PRIMARY KEY,
  message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  emoji TEXT NOT NULL,
  UNIQUE(message_id, user_id, emoji) -- A user can't React 🍉 twice to the same message
);
```

When a reaction is added, an HTTP request goes to `msg-service`, which inserts the row and publishes a `MESSAGE_REACTION_ADD` event to Redis. The mobile app aggregates identical emojis into a counter.

### Threads
Threads are just standard channels with a `parent_id` pointing to the originating channel, and a `thread_message_id` pointing to the message that spawned the thread.
When in a thread, the client subscribes to `channel:{thread_id}` instead of the parent.

---

## Message Editing & Deletion

Flicko supports message editing and soft-deleting.

### Editing
A `PATCH` request updates the `content` and sets `edited_at = NOW()`. A `MESSAGE_UPDATE` event is broadcasted. The mobile app shows an `(edited)` badge next to the timestamp.

### Deletion (Soft & Hard Delete)
When a user deletes their own message, or a Moderator deletes it:
1. `deleted_at = NOW()` is set in PostgreSQL.
2. `MESSAGE_DELETE` is broadcasted.
3. The mobile app removes the message from the UI.
*Note: Deleted messages are retained in the database for 30 days for Trust & Safety audit logging, but the API will never return them in standard fetches.*

---

## Full-Text Search

Flicko leverages PostgreSQL `tsvector` for instantaneous full-text search across millions of messages.

In `003_indexes.sql`:
```sql
ALTER TABLE messages ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
  setweight(to_tsvector('english', coalesce(content, '')), 'A')
) STORED;

CREATE INDEX idx_messages_search ON messages USING GIN(search_vector);
```

When a user uses the search bar, the Go API converts their input:
`"hello world"` → `to_tsquery('english', 'hello & world')`
This allows for lightning-fast matching without needing a heavy external dependency like Elasticsearch.

---

## Related Documentation

- [Architecture: Data Flow](../architecture/data-flow.md) — Sequence diagrams of these exact flows
- [Frontend: State Management](../architecture/state-management.md) — How the mobile app handles optimistic UI buffers

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
