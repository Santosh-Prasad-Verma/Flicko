# Backend Services (Business Logic Layer)

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

The service layer (`backend/internal/services/`) contains **95 files** implementing all business logic. Each service is a Go struct with methods that operate on the database and external integrations. Services are injected into handlers via constructor dependency injection — no global state.

Services are organized by domain and follow the pattern:
- `{domain}_service.go` — Implementation
- `{domain}_service_test.go` — Unit tests (table-driven)

---

## Service Inventory (95 files, by domain)

### Authentication & Sessions

| File | Size | Purpose |
|------|------|---------|
| `auth.go` | 5.2 KB | JWT token validation with HMAC primary + Supabase fallback. `ValidateToken()` is the core method called by the Auth middleware on every protected request. |
| `auth_test.go` | 1.7 KB | Tests for valid/invalid/expired tokens. |
| `session_service.go` | 7.3 KB | User session management including creation, refresh, revocation, and multi-device tracking. Sessions are stored in Redis with configurable TTL. |
| `session_service_test.go` | 2.4 KB | Session lifecycle tests. |
| `session_test.go` | 2.0 KB | Additional session edge case tests. |
| `password_validator.go` | 4.8 KB | Password strength validation with entropy calculation. Checks length (≥8), uppercase, lowercase, digits, special chars, and common password dictionary. |
| `connected_account_service.go` | 5.6 KB | OAuth provider account linking (Google, GitHub, Discord, Apple). |
| `connected_account_service_test.go` | 1.8 KB | OAuth link/unlink tests. |

### User & Profile

| File | Size | Purpose |
|------|------|---------|
| `user.go` | 2.9 KB | Core user CRUD — create, read, update, delete user profiles. |
| `user_test.go` | 2.8 KB | User CRUD tests. |
| `user_settings_service.go` | 3.4 KB | User preference management — theme, notification settings, appearance. |
| `user_settings_service_test.go` | 2.5 KB | Settings persistence tests. |
| `presence_service.go` | 3.3 KB | Online/idle/DnD/offline status tracking. Updates status in database and publishes change events for real-time presence. |
| `presence_service_test.go` | 1.5 KB | Presence state transition tests. |
| `activity_service.go` | 3.9 KB | Activity feed management — recording and retrieving user activities (messages, mentions, friend requests, etc.). |
| `activity_service_test.go` | 1.9 KB | Activity feed tests. |

### Server (Guild) Management

| File | Size | Purpose |
|------|------|---------|
| `server.go` | 3.3 KB | Server creation, update, delete. Enforces ownership and member count tracking. |
| `server_test.go` | 1.0 KB | Server CRUD tests. |
| `template_service.go` | 7.8 KB | Server templates — predefined channel/role configurations for quick server setup (e.g., "Gaming Community", "Study Group"). |
| `template_service_test.go` | 2.8 KB | Template application tests. |
| `community_service.go` | 5.5 KB | Community features — server discovery settings, categories, verification levels. |
| `community_service_test.go` | 1.1 KB | Community feature tests. |
| `community_event_service.go` | 5.1 KB | Scheduled community events — creation, RSVP, reminders. |
| `community_event_service_test.go` | 1.7 KB | Event scheduling tests. |
| `boost_service.go` | 6.6 KB | Server boosting system — boost tracking, tier calculation, perk unlocking. |
| `boost_webhook_test.go` | 2.3 KB | Boost webhook handling tests. |

### Channel & Messaging

| File | Size | Purpose |
|------|------|---------|
| `channel.go` | 3.0 KB | Channel CRUD — create, update, delete, reorder. Supports text, voice, category, announcement, forum, stage, dm types. |
| `channel_test.go` | 0.7 KB | Channel tests. |
| `message.go` | 3.1 KB | Message CRUD — create, read, update, soft-delete. Content validation (1-4000 chars). |
| `message_test.go` | 1.2 KB | Message tests. |
| `message_edit_service.go` | 3.7 KB | Message editing with edit history tracking and `edited_at` timestamp. |
| `message_edit_service_test.go` | 1.2 KB | Edit tests. |
| `mention_service.go` | 4.8 KB | @mention extraction and notification. Parses `<@userID>` patterns from message content, creates notifications for mentioned users. |
| `mention_service_test.go` | 1.5 KB | Mention parsing tests. |
| `pin_service.go` | 3.0 KB | Message pinning/unpinning with per-channel pin limits. |
| `pin_service_test.go` | 0.9 KB | Pin tests. |
| `embed_service.go` | 5.5 KB | Link preview / embed generation. Fetches OpenGraph metadata from URLs found in messages to generate rich embeds. |
| `embed_service_test.go` | 2.2 KB | Embed generation tests. |
| `crosspost_service.go` | 6.0 KB | Announcement channel crossposting — when a message is posted in an announcement channel, it can be crossposted to all servers following that channel. |
| `crosspost_service_test.go` | 1.6 KB | Crosspost tests. |
| `search_service.go` | 5.6 KB | Full-text message search with filters (author, channel, date range, content). Uses PostgreSQL `tsvector` indexes for performance. |

### Threading

| File | Size | Purpose |
|------|------|---------|
| `thread_service.go` | 7.2 KB | Thread creation from messages, name/archive settings, member management. |
| `thread_service_test.go` | 1.9 KB | Thread lifecycle tests. |
| `thread_member_service.go` | 5.4 KB | Thread member join/leave, muting, and notification preferences. |
| `thread_archive_service.go` | 3.7 KB | Auto-archiving of threads after inactivity (`auto_archive_duration`). |
| `thread_archive_service_test.go` | 1.3 KB | Archive timing tests. |

### Direct Messaging

| File | Size | Purpose |
|------|------|---------|
| `dm_message_service.go` | 6.1 KB | 1-on-1 direct message sending, reading, and deletion. |
| `dm_reaction_service.go` | 3.9 KB | Reactions on DM messages. |
| `dm_reaction_service_test.go` | 1.0 KB | DM reaction tests. |
| `group_dm_service.go` | 7.7 KB | Group DM management — create groups, add/remove members, group naming. |
| `group_dm_service_test.go` | 2.2 KB | Group DM tests. |
| `dm_call_service.ts` | — | (Cross-platform) Signaling coordinator for DM WebRTC calls. Orchestrates ringing, acceptance, and completion via the `dm_calls` coordination table. |

### Social Features

| File | Size | Purpose |
|------|------|---------|
| `friend_service.go` | 10.1 KB | Complete friendship system — send/accept/decline/block friend requests, mutual friends, friend list with presence. Largest social service file. |
| `friend_service_test.go` | 3.9 KB | Friendship lifecycle tests. |
| `notification_service.go` | 4.5 KB | Notification creation, marking as read, clearing. Supports mention, friend request, server invite, and reaction notification types. |

### Roles & Permissions

| File | Size | Purpose |
|------|------|---------|
| `role.go` | 2.0 KB | Role CRUD — create, update, delete, reorder roles within a server. |
| `permission_service.go` | 2.5 KB | Permission calculation from role bitfields. Computes effective permissions by combining role permissions with channel overwrites. |
| `permission_service_test.go` | 2.5 KB | Permission calculation tests. |
| `permission_overwrite_service.go` | 3.1 KB | Channel-specific permission overrides for roles and individual users. |
| `permission_overwrite_service_test.go` | 1.5 KB | Overwrite tests. |
| `member_role_service.go` | 4.9 KB | Role assignment/removal for server members. |
| `member_role_service_test.go` | 1.3 KB | Role assignment tests. |

### Invites

| File | Size | Purpose |
|------|------|---------|
| `invite_service.go` | 6.2 KB | Invite code generation, validation, usage tracking, and expiry. Supports max-use limits and time-based expiry. |
| `invite_service_test.go` | 2.0 KB | Invite lifecycle tests. |

### Moderation & Reporting

| File | Size | Purpose |
|------|------|---------|
| `warning_service.go` | 8.3 KB | Warning system with escalating punishments. Tracks warning count per user per server, applies automatic actions at thresholds (3 warnings → mute, 5 → kick, etc.). |
| `warning_service_test.go` | 3.2 KB | Warning escalation tests. |
| `report_service.go` | 8.9 KB | User/message report system. Supports reporting for harassment, spam, NSFW, and other categories. Includes report queue for moderator review. |
| `report_service_test.go` | 2.6 KB | Report handling tests. |
| `audit_service.go` | 4.3 KB | Audit log recording — tracks who did what, when, to which resource. Used by moderation bots and admin panels. |
| `audit_service_test.go` | 1.8 KB | Audit log tests. |
| `automod_service.go` | 14.2 KB | AutoMod engine — the second-largest service file. Implements 8 content filters (invites, links, caps, emoji spam, mass mentions, duplicate messages, word blacklist, spam detection). Each filter is configurable per-server. |
| `automod_service_test.go` | 5.7 KB | AutoMod filter tests (most comprehensive test file). |

### Voice & Video

| File | Size | Purpose |
|------|------|---------|
| `voice_service.go` | 6.2 KB | Voice channel state management — join, leave, mute, deaf, suppress. Tracks active voice states in the database. |
| `voice_service_test.go` | 1.4 KB | Voice state tests. |
| `stream_service.go` | 13.7 KB | Screen sharing and streaming — create streams, manage viewers, track quality settings. |
| `screen_share_service.go` | 5.7 KB | Screen share specific logic — start/stop, viewer notifications, quality optimization. |
| `screen_share_service_test.go` | 1.5 KB | Screen share tests. |

### Media & Storage

| File | Size | Purpose |
|------|------|---------|
| `attachment_service.go` | 3.4 KB | File attachment metadata management — tracking URLs, MIME types, sizes. |
| `attachment_service_test.go` | 2.1 KB | Attachment tests. |
| `attachment_cleanup.go` | 4.1 KB | Orphaned attachment cleanup — periodically removes attachments whose messages have been deleted. |
| `attachment_cleanup_test.go` | 2.1 KB | Cleanup scheduling tests. |
| `sticker_service.go` | 5.7 KB | Custom sticker management — upload, list, delete server stickers. |
| `sticker_service_test.go` | 2.1 KB | Sticker tests. |
| `drawing_service.go` | 4.5 KB | Collaborative drawing canvas — save/load drawing state for whiteboard channels. |
| `drawing_service_test.go` | 1.6 KB | Drawing persistence tests. |

### Webhooks

| File | Size | Purpose |
|------|------|---------|
| `webhook_service.go` | 7.1 KB | Webhook management — create, update, delete webhooks per channel. Handles webhook message delivery with retry logic. |

### Performance & Monitoring

| File | Size | Purpose |
|------|------|---------|
| `performance_service.go` | 8.0 KB | Performance metrics collection — query latency tracking, connection pool stats, cache hit rates. Flutterses data for Prometheus scraping. |
| `performance_service_test.go` | 1.5 KB | Metrics collection tests. |

---

## Dependency Injection Pattern

All services receive their dependencies via constructor injection:

```go
type AutoModService struct {
    db     *pgx.Pool
    redis  *redis.Client
    logger *zap.Logger
}

func NewAutoModService(db *pgx.Pool, redis *redis.Client, logger *zap.Logger) *AutoModService {
    return &AutoModService{db: db, redis: redis, logger: logger}
}
```

Services are instantiated in `main.go` and passed to handlers:

```go
autoModService := services.NewAutoModService(db, redisClient, logger)
botHandler := handlers.NewBotHandler(modService, autoModService, ..., logger)
```

---

## Test Coverage

**42 test files** covering the service layer. All tests follow Go's table-driven test pattern:

```go
func TestWarningService_Escalation(t *testing.T) {
    tests := []struct {
        name           string
        warningCount   int
        expectedAction string
    }{
        {"first warning", 1, "warning"},
        {"third warning", 3, "mute"},
        {"fifth warning", 5, "kick"},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // ... test logic
        })
    }
}
```

---

## Related Docs
- [Backend Overview](overview.md) — Architecture context
- [Controllers](controllers.md) — HTTP handler layer
- [Models](models.md) — Data structures
- [Error Handling](error-handling.md) — Error patterns
