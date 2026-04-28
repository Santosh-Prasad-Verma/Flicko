# Direct Messaging

> **Reading time:** ~12 minutes · **Audience:** Backend, Mobile Developers · **Last Updated:** 2026-04-11

Flicko supports private conversations outside of servers. The Direct Messaging (DM) architecture supports both 1-on-1 chats and group conversations with up to 10 participants, using a strict participant-based security model.

---

## Table of Contents

- [The Conversation Model](#the-conversation-model)
- [1-on-1 vs Group DMs](#1-on-1-vs-group-dms)
- [Message Delivery & Real-Time Sync](#message-delivery--real-time-sync)
- [Block System Integration](#block-system-integration)
- [DM Voice & Video Calls](#dm-voice--video-calls)

---

## The Conversation Model

Unlike server messages which belong to a Channel, private messages belong to a Conversation.

**Schema Overview:**
- `dm_conversations`: Holds metadata (`id`, `is_group`, `name`, `updated_at`).
- `dm_participants`: Associative table mapping `user_id` to `conversation_id`.
- `dm_messages`: Holds the actual chat text mapping to the `conversation_id`.

**Why a separate `dm_messages` table?**
While we could theoretically reuse the `messages` table, DMs have different schema requirements (no threads, different permission/RLS models) and vastly different data retention policies. Keeping them separate prevents the `messages` table from bloating with billions of private, non-searchable rows.

---

## 1-on-1 vs Group DMs

The backend handles the creation of a DM conversation defensively to prevent duplication.

### 1-on-1 DMs
When User A wants to message User B:
1. `GET /api/v1/users/B/dm` is called.
2. The `msg-service` executes a complex JOIN query to see if a conversation ALREADY exists where `is_group = false` AND the only two participants are A and B.
3. If yes, it returns the existing `conversation_id`.
4. If no, it creates a new `dm_conversations` row, inserts 2 rows into `dm_participants`, and returns the new ID.

### Group DMs
Group DMs allow up to 10 users.
1. User calls `POST /api/v1/dms/group` with an array of user IDs.
2. The backend creates a new conversation with `is_group = true`. Unlike 1-on-1s, group DMs are never deduplicated — you can have multiple separate group chats with the exact same 3 people.
3. Group DMs can have a custom `name` assigned. If null, the mobile app dynamically generates a name by concatenating the participants' usernames (e.g., "tarun, alex, john").

---

## Message Delivery & Real-Time Sync

The message flow is nearly identical to Server channels, but utilizes a different Redis Channel naming convention.

**REST API:**
`POST /api/v1/dms/{conversationId}/messages`

**Redis Pub/Sub Channel:**
`dm:{conversation_id}`

### Resolving Subscribers
If User A sends a message to User B in `conversation_123`, the event is published to `dm:123`.

*How does User B's WebSocket connection know to listen to `dm:123`?*
When User B connects, the `ws-gateway` queries the database for all 1-on-1 and Group DMs where User B is a participant in `dm_participants`, and Subscribes to those Redis channels automatically, alongside their server channels.

### Notification Pushes
Because DMs are high-priority, a `DM_MESSAGE_CREATE` event triggers an out-of-band call to the Supabase Edge Function to deliver a native iOS/Android Push Notification, even if the user is offline.

---

## Block System Integration

Flicko prevents harassment by enforcing blocks at the DM level.

Before creating a message in a 1-on-1 DM, the `dmService` checks the `friends` table:
```sql
SELECT status FROM friends 
WHERE (user_id = $1 AND friend_id = $2) 
   OR (user_id = $2 AND friend_id = $1);
```
If the status is `blocked`, the API returns `403 Forbidden` with the error `Cannot send message. User block enforced.`

If a user tries to create a Group DM incorporating a user they have blocked (or who has blocked them), the creation request fails.

---

## DM Voice & Video Calls

1-on-1 and Group DMs support low-latency WebRTC voice and video communication.

### Signaling Flow
Flicko uses a coordination table `dm_calls` to orchestrate calls without a persistent voice channel.
1. **Initiation**: When User A calls User B, a record is inserted into `dm_calls` with status `ringing`.
2. **Real-time Alert**: Recipients listen to the `dm_calls` table via Supabase Realtime.
3. **UI Response**: The `IncomingCallDialog` appears globally on the recipient's device.
4. **Acceptance**: When accepted, the status updates to `accepted`, and both parties are issued LiveKit room tokens.
5. **Media**: The `conversation_id` serves as the LiveKit room name, ensuring all participants join the same private media session.

### State Management
Call state is managed via the `useDMCallStore` Riverpod store, which handles ringing durations, visibility of the call dialog, and clean-up of the call record when the conversation ends.

---

## Related Documentation

- [Features: Real-Time Messaging](real-time-messaging.md) — The message batching engine (which also processes DMs)
- [Architecture: Data Flow](../architecture/data-flow.md) — The sequence diagram for initiating a DM

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
