# Bot System Framework

> **Reading time:** ~20 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

Flicko ships with 8 built-in bots that provide moderation, utility, and engagement features to servers. Instead of running these as external scripts polling an API (the Discord model), Flicko embeds them directly into the Go `backend` monolith using an efficient, in-process Event Bus.

---

## Table of Contents

- [The Internal Event Bus](#the-internal-event-bus)
- [Bot Registry Pattern](#bot-registry-pattern)
- [Slash Command Router](#slash-command-router)
- [The 8 Built-in Bots](#the-8-built-in-bots)
- [Creating a New Bot](#creating-a-new-bot)
- [Bot Database Schema](#bot-database-schema)

---

## The Internal Event Bus

The `backend` service is entirely event-driven. It listens to the Redis Pub/Sub channels where `msg-service` publishes events (like `MESSAGE_CREATE` or `MEMBER_JOIN`), unmarshals those payloads into strongly typed Go structs, and pumps them into the `events.Bus`.

**Event Structure (`backend/internal/events/events.go`):**
```go
type EventType string

const (
    MsgCreate   EventType = "MESSAGE_CREATE"
    MsgDelete   EventType = "MESSAGE_DELETE"
    MemberJoin  EventType = "MEMBER_JOIN"
    MemberLeave EventType = "MEMBER_LEAVE"
    ReactAdd    EventType = "REACTION_ADD"
)

type Event struct {
    Type      EventType
    ServerID  uuid.UUID // Crucial for filtering
    ChannelID uuid.UUID
    UserID    uuid.UUID
    Payload   json.RawMessage
}
```

The Bus allows any component to register a handler func for a specific EventType. When the payload arrives, it's executed in a new goroutine.

---

## Bot Registry Pattern

All 8 bots reside in `backend/internal/bots/`. They must implement the `Bot` interface:

```go
type Bot interface {
    ID() string                     // Unique identifier (e.g., "automod")
    Name() string                   // Human readable
    Description() string
    Init(b *events.Bus, r *commands.Router, db *sql.DB) error
}
```

**Initialization (`server/main.go`):**
At startup, `main.go` creates the Registry, instantiates each bot, and calls `Register()`. The registry then calls `Init()` on every bot, passing it the Event Bus, the Command Router, and the database connection.

This design gives every bot direct SQL access. For example, the Leveling bot executes `UPDATE user_xp SET xp = xp + 15` instantly without HTTP overhead.

---

## Slash Command Router

The `msg-service` detects messages that start with `/` and publishes them to Redis with a special `COMMAND_CREATE` internal type. The `backend` receives this and routes it to `commands.Router`.

**Command Registration:**
Bots register their commands during `Init()`:
```go
func (m *ModerationBot) Init(b *events.Bus, r *commands.Router, db *sql.DB) error {
    // ...
    r.RegisterCommand(&commands.CommandDefinition{
        Name:        "ban",
        Description: "Ban a user from the server",
        Options: []commands.Option{
            {Name: "user", Type: commands.TypeUser, Required: true},
            {Name: "reason", Type: commands.TypeString, Required: false},
        },
        RequiredPerms: permissions.BanMembers,
        Handler:       m.handleBan,
    })
    return nil
}
```

The Router automatically checks RBAC permissions before invoking the `Handler`. If a user with no permissions types `/ban`, the router intercepts it and sends a red UI error back to the user without the bot ever knowing.

---

## The 8 Built-in Bots

| Bot | ID | Primary Loop | DB Tables |
|-----|----|--------------|-----------|
| **AutoMod** | `automod` | Listens to `MESSAGE_CREATE`. Runs 8 regex/logic filters against payload. If triggered, performs action (Delete, Warn, Mute). | `automod_settings` |
| **Moderation** | `mod` | Registers Slash Commands (`/ban`, `/kick`, `/purge`). Executes actions and logs to mod-log channel. | `mod_settings`, `warnings` |
| **Welcome** | `welcome` | Listens to `MEMBER_JOIN` / `MEMBER_LEAVE`. Injects template variables (`{user}`, `{server}`) and sends greeting message. Assigns default auto-role. | `welcome_settings` |
| **Leveling** | `level` | Listens to `MESSAGE_CREATE`. Calculates XP cooldowns, awards random XP, checks for level-ups via mathematically derived curve. | `level_settings`, `user_xp` |
| **Ticket** | `ticket` | Registers Slash `/ticket`. Creates private channel, sets permission overwrites, sends action buttons for staff. | `ticket_settings`, `tickets` |
| **Starboard** | `starboard` | Listens to `REACTION_ADD`. If emoji == ⭐ and count >= threshold, cross-posts message to starboard channel using a Message Embed. | `starboard_settings`, `starboard_entries` |
| **Poll** | `poll` | Registers Slash `/poll`. Constructs special JSON payload that mobile app renders as interactive UI. Listens to clicks via generic component interactions. | None (Stateless JSON) |
| **Music** | `music` | Listens to Slash `/play`. Connects to LiveKit room. Implements `SyncMusicBot` handler to synchronize playback state (track, position, queue) for all participants. | None |

---

## Creating a New Bot

1. Create `backend/internal/bots/mybot.go`.
2. Define setting struct corresponding to database table.
3. Implement `Bot` interface.
4. Subscribe to events or register commands in `Init()`.
5. Add to `var BuiltInBots` slice in `backend/internal/bots/registry.go`.
6. Add toggle to `mobile/app/server/[id]/settings/bots.tsx` so users can enable it.

---

## Bot Database Schema

Bot configurations use a hybrid approach to accommodate varying complexity:

- **Simple settings** use standard columns (e.g., `mod_settings` has `dm_on_warn boolean`, `mod_log_channel_id uuid`).
- **Complex logic trees** use PostgreSQL `JSONB` columns. For example, `automod_settings.filters` stores a flexible JSON object defining which of the 8 filters are enabled and their unique thresholds. The backend unmarshals this `JSONB` directly into Go configuration structs.

*Note: All bot setting tables have a foreign key to `servers(id) ON DELETE CASCADE`, ensuring no orphan settings remain if a server is deleted.*

---

## Related Documentation

- [Features: Moderation](moderation.md) — Deep dive into the AutoMod logic
- [Backend: Overview](../backend/overview.md) — How the backend monolith runs these bots
- [Database: Schema](../database/schema.md) — The exact SQL schema for bot settings

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
