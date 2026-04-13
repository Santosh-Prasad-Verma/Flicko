# Backend Models

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

Backend models are Go structs that represent database entities and API request/response shapes. There are **22 model files** in `backend/internal/models/`, each defining one or more structs with JSON tags for API serialization and database column mappings.

---

## Model Inventory

### `user.go` — User Model
```go
type User struct {
    ID           uuid.UUID  `json:"id" db:"id"`
    Username     string     `json:"username" db:"username"`
    Email        string     `json:"email" db:"email"`
    PasswordHash string     `json:"-" db:"password_hash"` // Never serialized to JSON
    AvatarURL    *string    `json:"avatar_url" db:"avatar_url"`
    BannerURL    *string    `json:"banner_url" db:"banner_url"`
    Theme        string     `json:"theme" db:"theme"`
    CreatedAt    time.Time  `json:"created_at" db:"created_at"`
    UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}
```
**Notable:** `PasswordHash` uses `json:"-"` to prevent accidental exposure in API responses.

### `server.go` — Server (Guild) Model
```go
type Server struct {
    ID          uuid.UUID `json:"id"`
    Name        string    `json:"name"`
    Description *string   `json:"description"`
    OwnerID     uuid.UUID `json:"owner_id"`
    IconURL     *string   `json:"icon_url"`
    BannerURL   *string   `json:"banner_url"`
    MemberCount int       `json:"member_count"`
    CreatedAt   time.Time `json:"created_at"`
    UpdatedAt   time.Time `json:"updated_at"`
}
```

### `channel.go` — Channel Model
Supports all channel types: `text`, `voice`, `category`, `announcement`, `forum`, `stage`, `dm`.

### `message.go` — Message Model
Core messaging model with support for replies (`reply_to_id`), threads (`thread_id`), embeds, attachments, mentions, and soft-delete via `deleted_at`.

### `role.go` — Role Model
Permission system using **64-bit integer bitfield** for efficient permission storage and checking:
```go
type Role struct {
    ID          uuid.UUID `json:"id"`
    ServerID    uuid.UUID `json:"server_id"`
    Name        string    `json:"name"`
    Color       *string   `json:"color"`
    Position    int       `json:"position"`
    Permissions int64     `json:"permissions"` // Bitfield
}
```

### `moderation.go` — Moderation Models
Warning, ban, mute, and kick action records with timestamps and reasons.

### `voice.go` — Voice State Model
Tracks user presence in voice channels with mute/deaf/suppress states.

### `thread.go` — Thread Model
Thread metadata including parent channel, archive settings, member count, and last activity.

### `boost.go` — Server Boost Model
Boost tracking with creation date, tier information, and perk data.

### `social.go` — Social Relationship Models
Friend requests, blocked users, and mutual friend data.

### `activity.go` — Activity Feed Model
Activity items with type (message, mention, friend request, etc.), content, and metadata.

### `sticker.go` — Sticker Model
Custom sticker metadata including name, image URL, and server association.

### `community.go` — Community Event Model
Scheduled events with title, description, start/end time, RSVP tracking.

### `audit.go` — Audit Log Entry Model
Action records for moderation tracking.

### `drawing.go` — Drawing Canvas Model
Collaborative drawing state storage.

### `session.go` — Session Model
User session tracking with device info, IP address, and last activity.

### `user_settings.go` — User Settings Model
Preference storage for theme, notifications, privacy, and accessibility.

### `connected_account.go` — OAuth Connected Account
External provider accounts (Google, GitHub, Discord, Apple).

### `member.go` — Server Member
Server membership with optional nickname.

### `invite.go` — Invite Code Model
Invite codes with expiry, max uses, and usage tracking.

### `dm.go` — Direct Message Conversation
DM and group DM conversation containers.

### `attachment.go` / `reaction.go` — Message Sub-models
Attachment metadata and reaction data.

---

## TypeScript Shared Models

The frontend uses TypeScript interfaces (`shared/types/models.ts`) that mirror the Go models:

| Go Model | TypeScript Interface | Key Differences |
|----------|---------------------|-----------------|
| `User` | `User` | TS adds `badges`, `pronouns`, `display_name` |
| `Server` | `Server` | Same fields |
| `Channel` | `Channel` | TS uses `ChannelType` union type |
| `Message` | `Message` | TS includes nested `author?`, `reply_to?`, `thread?` |
| `Role` | (in stores) | Permissions handled client-side |
| `VoiceState` | `VoiceState` | Same fields |
| `Member` | `Member` | TS includes nested `user?` |
| N/A | `Poll`, `PollOption`, `PollVote` | TS-only poll types |
| N/A | `ActivityItem`, `Friend` | TS-only social types |

---

## Related Docs
- [Database Schema](../database/schema.md) — Column-level reference
- [Services](services.md) — Business logic using these models
- [Controllers](controllers.md) — API response shapes
