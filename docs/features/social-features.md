# Social Features

> **Reading time:** ~12 minutes · **Audience:** Backend, Mobile Developers · **Last Updated:** 2026-04-11

This document covers the systems that build relationships between users outside of servers, including the Friend list, the Block list, custom status messages, and online presence tracking.

---

## Table of Contents

- [The Friendship Lifecycle](#the-friendship-lifecycle)
- [Online Presence Tracking](#online-presence-tracking)
- [User Profiles & Custom Status](#user-profiles--custom-status)
- [Push Notifications](#push-notifications)

---

## The Friendship Lifecycle

Relationships in Flicko use a unidirectional-request, bidirectional-acceptance model managed in the `friends` table.

### Schema
```sql
CREATE TABLE friends (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  friend_id UUID REFERENCES users(id),
  status TEXT CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);
```

### Flow Map

1. **Send Request:** A sends request to B.
   - Insert: `(user=A, friend=B, status='pending')`
   - B receives `FRIEND_REQUEST` event in Redis channel `user:{B}`.

2. **Accept Request:** B accepts.
   - Update: `(user=A, friend=B, status='accepted')`
   - Insert reverse link: `(user=B, friend=A, status='accepted')` (Creates a true bidirectional edge for fast querying).
   - A receives `FRIEND_ACCEPTED` event in Redis channel `user:{A}`.

3. **Decline Request:** B declines.
   - Delete: Row where `user=A AND friend=B`.

4. **Block:** A blocks B.
   - If they are currently friends, delete the bidirectional `'accepted'` rows.
   - Insert: `(user=A, friend=B, status='blocked')`
   - This row is checked by the Direct Message and Group DM services to enforce harassment protection.

---

## Online Presence Tracking

One of the most complex scaling challenges in a chat app is accurate "Online/Offline" indicators tracking across thousands of connections without hammering the database.

Flicko solves this using **Redis Keyspace Notifications** and in-memory Maps in the `ws-gateway`.

### The `ws-gateway` Presence Hub

When a user connects a WebSocket, the gateway emits:
1. `SET user:{user_id}:presence "online" EX 45` (Redis key with 45-second expiry).
2. It broadcasts `PRESENCE_UPDATE` to all servers the user shares with others.

Every 30 seconds, the client sends an `OpHeartbeatAck`. The gateway receives this and issues an `EXPIRE user:{user_id}:presence 45`, keeping the key alive.

### Disconnections & The TTL Hack
If a user closes their phone, the socket drops. We don't want them looking "Online" for a long time. 
Because the Redis key has a 45-second TTL, if the gateway crashes or fails to emit a clean offline event, Redis automatically expires the key. A background worker subscribes to Redis `__keyevent@0__:expired` events, detects the user's presence key expired, and broadcasts a `PRESENCE_UPDATE {status: "offline"}`.

### Custom Statuses
Users can manually set their status to "Idle", "Do Not Disturb" (DnD), or "Invisible". 
If DnD is selected, the mobile app intercepts incoming push notifications and mutes their sound/vibration locally.

---

## User Profiles & Custom Status

A user's identity is defined in the `users` table.

```json
{
  "username": "tarun",
  "display_name": "Tarun",
  "avatar_url": "https://res.cloudinary.com/...",
  "banner_url": "https://res.cloudinary.com/...",
  "bio": "Building Flicko",
  "status_text": "Coding...",
  "status_emoji": "👨‍💻",
  "badges": ["early_supporter", "staff"]
}
```

Updating the profile triggers a `USER_PROFILE_UPDATE` event across all shared servers, immediately changing the user's avatar and bio for everyone looking at them. The mobile UI aggressively caches profiles using `@tanstack/react-query` to ensure fast rendering of message lists.

---

## Push Notifications

Push notifications are critical for social engagement but cannot be handled reliably by standard HTTP timeouts.

Flicko uses an asynchronous Supabase Edge Function to deliver payloads to Apple APNs and Google FCM via the Expo Push API.

**The Pipeline:**
1. User receives a DM. `msg-service` writes to DB.
2. `msg-service` checks if the recipient is currently connected to `ws-gateway`. If yes, it skips push notification (they are looking at the app).
3. If no, `msg-service` triggers the `push-notification` Edge Function via an internal webhook.
4. The Edge Function looks up the user's `expo_push_token` (registered when they logged in on the mobile app).
5. The Edge Function posts the payload to `https://exp.host/--/api/v2/push/send`.
6. Expo delivers the native notification to the device.

---

## Related Documentation

- [Features: Direct Messaging](direct-messaging.md) — How the Block list integrates into DM creation
- [Architecture: Data Flow](../architecture/data-flow.md) — Visual flow of the Friend Request lifecycle

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
