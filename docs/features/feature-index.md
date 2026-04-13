# Feature Index

> **Reading time:** ~10 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

This document is the master index of all core features available in Flicko. For each feature, you will find its implementation status, the backend service responsible for its business logic, the key database tables it relies on, and links to detailed technical documentation.

---

## 💬 Communication

| Feature | Status | Core Service | Database Tables | Docs |
|---------|--------|-------------|-----------------|------|
| **Real-time Messaging** | ✅ Complete | `msg-service` | `messages` | [Messaging](real-time-messaging.md) |
| **Direct Messaging** | ✅ Complete | `msg-service` | `dm_conversations`, `dm_messages` | [DMs](direct-messaging.md) |
| **Typing Indicators** | ✅ Complete | `ws-gateway` | — (Redis Pub/Sub only) | [Messaging](real-time-messaging.md) |
| **Message Reactions** | ✅ Complete | `msg-service` | `reactions` | [Messaging](real-time-messaging.md) |
| **Message Threads** | ✅ Complete | `msg-service` | `threads` | [Messaging](real-time-messaging.md) |
| **Message Editing** | ✅ Complete | `msg-service` | `messages` (edited_at) | [Messaging](real-time-messaging.md) |
| **Read Receipts** | 🏗️ In Progress | `msg-service` | `read_states` | [Messaging](real-time-messaging.md) |
| **Global Search** | ✅ Complete | `msg-service` | `messages` (tsvector idx) | [Messaging](real-time-messaging.md) |

---

## 🎙️ Voice & Video

| Feature | Status | Core Service | Database Tables | Docs |
|---------|--------|-------------|-----------------|------|
| **Voice Channels** | ✅ Complete | `backend` | `voice_states` | [Voice & Video](voice-and-video.md) |
| **Video Calls** | ✅ Complete | `backend` | `voice_states` | [Voice & Video](voice-and-video.md) |
| **Screen Sharing** | ✅ Complete | `backend` | `voice_states` | [Voice & Video](voice-and-video.md) |
| **Push-to-Talk** | ✅ Complete | — (Client side) | — | [Voice & Video](voice-and-video.md) |
| **Voice Activity Det.** | ✅ Complete | — (LiveKit) | — | [Voice & Video](voice-and-video.md) |
| **DM Calls** | 🏗️ Planned | `backend` | `voice_states` | [Voice & Video](voice-and-video.md) |

---

## 🛡️ Server Management & Moderation

| Feature | Status | Core Service | Database Tables | Docs |
|---------|--------|-------------|-----------------|------|
| **Server Creation** | ✅ Complete | `backend` | `servers` | [Server Mgmt](server-management.md) |
| **Channel Categories** | ✅ Complete | `backend` | `channels` | [Server Mgmt](server-management.md) |
| **RBAC / Roles** | ✅ Complete | `backend` | `roles`, `member_roles` | [Server Mgmt](server-management.md) |
| **Permission Overrides**| ✅ Complete | `backend` | `permission_overwrites` | [Server Mgmt](server-management.md) |
| **Invite System** | ✅ Complete | `backend` | `invites` | [Server Mgmt](server-management.md) |
| **Manual Moderation** | ✅ Complete | `backend` | `warnings` | [Moderation](moderation.md) |
| **Audit Logging** | ✅ Complete | `backend` | `audit_logs` | [Moderation](moderation.md) |
| **Server Discovery** | 🏗️ Planned | `backend` | `servers` (is_public) | [Server Mgmt](server-management.md) |

---

## 🤖 Bot System

| Feature | Status | Core Service | Database Tables | Docs |
|---------|--------|-------------|-----------------|------|
| **Bot Framework** | ✅ Complete | `backend` | `bots` | [Bot System](bot-system.md) |
| **Slash Commands** | ✅ Complete | `backend` | — | [Bot System](bot-system.md) |
| **AutoMod Bot** | ✅ Complete | `backend` | `automod_settings` | [Moderation](moderation.md) |
| **Moderation Bot** | ✅ Complete | `backend` | `mod_settings` | [Moderation](moderation.md) |
| **Welcome Bot** | ✅ Complete | `backend` | `welcome_settings` | [Bot System](bot-system.md) |
| **Leveling Bot** | ✅ Complete | `backend` | `level_settings`, `user_xp` | [Bot System](bot-system.md) |
| **Music Bot** | 🏗️ In Progress | `backend` | — | [Bot System](bot-system.md) |
| **Ticket Bot** | ✅ Complete | `backend` | `ticket_settings`, `tickets` | [Bot System](bot-system.md) |
| **Poll Bot** | ✅ Complete | `backend` | `messages` (JSON payload) | [Bot System](bot-system.md) |
| **Starboard Bot** | ✅ Complete | `backend` | `starboard_settings` | [Bot System](bot-system.md) |

---

## 👤 Social & Profiles

| Feature | Status | Core Service | Database Tables | Docs |
|---------|--------|-------------|-----------------|------|
| **Friend System** | ✅ Complete | `backend` | `friends` | [Social Features](social-features.md) |
| **User Blocking** | ✅ Complete | `backend` | `friends` (status='blocked') | [Social Features](social-features.md) |
| **Online Presence** | ✅ Complete | `ws-gateway` | — (Redis caching) | [Social Features](social-features.md) |
| **Custom Status** | ✅ Complete | `msg-service` | `users` | [Social Features](social-features.md) |
| **User Profiles** | ✅ Complete | `msg-service` | `users` | [Social Features](social-features.md) |
| **Push Notifications** | ✅ Complete | Edge Func | `push_tokens` | [Social Features](social-features.md) |

---

## 📸 Media & Integration

| Feature | Status | Core Service | Database Tables | Docs |
|---------|--------|-------------|-----------------|------|
| **Avatar/Banner Upload**| ✅ Complete | `backend` | `users` | [Media & Uploads](media-and-uploads.md) |
| **Message Attachments** | ✅ Complete | `msg-service` | `messages` (JSON array) | [Media & Uploads](media-and-uploads.md) |
| **GIF Search** | ✅ Complete | Edge Func | — | [Media & Uploads](media-and-uploads.md) |
| **Custom Emoji** | 🏗️ Planned | `backend` | `emojis` | [Media & Uploads](media-and-uploads.md) |

---

## 💎 Premium (Flicko Plus)

| Feature | Status | Core Service | Database Tables | Docs |
|---------|--------|-------------|-----------------|------|
| **Subscription Billing**| ✅ Complete | `backend` | `users` (stripe_id) | [Subscriptions](subscriptions.md) |
| **Animated Avatars** | ✅ Complete | `msg-service` | `users` | [Subscriptions](subscriptions.md) |
| **Upload Limits** | ✅ Complete | `backend` | — (MW check) | [Subscriptions](subscriptions.md) |
| **Server Boosting** | 🏗️ Planned | `backend` | `server_boosts` | [Subscriptions](subscriptions.md) |

---

## Related Documentation

- Click on any link in the **Docs** column above to view deep technical documentation for that specific feature.
- See [API Reference](../api/api-overview.md) for endpoint specifications.
- See [Database Schema](../database/schema.md) for the actual table structures mentioned above.

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
