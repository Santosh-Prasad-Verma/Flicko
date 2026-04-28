# Moderation System

> **Reading time:** ~15 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

To maintain safe communities, Flicko provides a comprehensive moderation architecture combining manual moderator tools with an automated content filtering engine (AutoMod).

---

## Table of Contents

- [The Warning Escalation System](#the-warning-escalation-system)
- [Manual Moderation (Slash Commands)](#manual-moderation-slash-commands)
- [AutoMod Engine](#automod-engine)
- [AutoMod Filters Details](#automod-filters-details)
- [Audit Logging](#audit-logging)
- [User Reporting](#user-reporting)

---

## The Warning Escalation System

Instead of relying solely on binary bans, Flicko implements a warning-based strike system designed for community rehabilitation. All warnings are logged in the `warnings` database table.

**The Escalation Ladder:**
When a warning is added (either manually by a mod or automatically by AutoMod), the backend tallies the user's total active warnings in that server. It then triggers an automatic response based on the count:

- **1-2 Warnings:** User receives a direct message explaining the rule violation (if `dm_on_warn` is enabled in `mod_settings`).
- **3 Warnings:** User receives an automatic temporary mute (Timeout) for 1 hour.
- **5 Warnings:** User is kicked from the server (can rejoin via invite).
- **7 Warnings:** User is permanently banned.

Warnings expire after 90 days. This logic resides in `backend/internal/services/mod_service.go`.

---

## Manual Moderation (Slash Commands)

Moderators interact with the system via Slash Commands processed by the `commands.Router`. The backend enforces that the invoking user possesses the corresponding RBAC bit.

| Command | Required Permission | Action Taken |
|---------|---------------------|--------------|
| `/warn @user {reason}` | `KICK_MEMBERS` | Inserts row into `warnings`. Evaluates escalation ladder. |
| `/mute @user {duration}` | `MUTE_MEMBERS` | Calculates expiration time. Updates member record. Muted users cannot send messages or speak in voice channels (enforced by middleware). |
| `/unmute @user` | `MUTE_MEMBERS` | Clears mute expiration timestamp. |
| `/kick @user {reason}` | `KICK_MEMBERS` | Deletes row from `members` table. Deletes all `member_roles`. Creates Audit Log entry. |
| `/ban @user {reason}` | `BAN_MEMBERS` | Deletes member row. Inserts row into `server_bans` table (which prevents future invites from working for that `user_id`). |
| `/unban {user_id}` | `BAN_MEMBERS` | Removes row from `server_bans`. |
| `/purge {count}` | `MANAGE_MESSAGES` | Bulk deletes up to 100 recent messages in the current channel. Handled in a single SQL transaction for speed. |

---

## AutoMod Engine

The AutoMod Engine is an event-driven system running inside the `backend` monolith. It listens to the `MESSAGE_CREATE` event bus payload.

**Execution Flow:**
1. A user sends a message. The `msg-service` successfully persists it and publishes it to Redis.
2. The `backend` receives the Redis event and triggers the AutoMod Bot handler in a new goroutine.
3. The AutoMod Engine fetches the server's `automod_settings` JSONB from PostgreSQL.
4. If AutoMod is enabled, the message content is passed sequentially through all 8 filters.
5. If **ANY** filter triggers, the engine executes the configured `action` (e.g., Delete Message, Add Warning).
6. If the action was `delete`, the engine deletes the row from PostgreSQL and publishes a `MESSAGE_DELETE` event via Redis to remove it from all clients' screens.

*Note: The message briefly exists on clients' screens before vanishing. This is by design to ensure that valid messages are never delayed by AutoMod processing overhead.*

---

## AutoMod Filters Details

The `automod_settings.filters` JSON structure defines behavior. Server owners can toggle each independently via the Flutter settings UI.

1. **Invite Links:** Uses regex to block `discord.gg/`, `flicko.app/join/`, and similar platform invite domains to prevent server raiding.
2. **External Links:** Deletes messages containing any HTTP link, unless the domain is present in the `whitelist` configuration array.
3. **Excessive Caps:** Triggers if message length > 15 characters AND the percentage of uppercase characters exceeds the configured `threshold` (default 70%).
4. **Emoji Spam:** Triggers if a single message contains more than the configured `max_per_message` emojis (unicode or custom).
5. **Mass Mentions:** Prevents `@user` mention spam. Triggers if the count of unique user mentions exceeds `max_mentions`.
6. **Duplicate Messages (Flood):** Maintains a fast rolling window in Redis. If a user sends the exact same string multiple times within `time_window` seconds, it triggers.
7. **Word Blacklist:** A custom string array of forbidden words. Evaluated using word boundary bounds (`\b`) to prevent substring blocking (e.g., blocking "ass" shouldn't block "glass").
8. **Spam Detection:** Advanced heuristic checking. Maintains a Redis cache of the user's last 5 messages. If the Levenshtein distance indicates high similarity sent within seconds, it triggers.

---

## Audit Logging

Every moderation action, manual or automated, generates an Audit Log entry in the `audit_logs` table.

```json
{
  "id": "123e4567...",
  "server_id": "890e...",
  "action_type": "MEMBER_BAN_ADD",
  "actor_id": "moderator_uuid",
  "target_id": "spammer_uuid",
  "reason": "Phishing links",
  "created_at": "2026-04-11T12:00:00Z"
}
```

If the server has `mod_log_channel_id` configured in `mod_settings`, the backend will additionally format the audit log entry as a visually rich Message payload and send it to that specific text channel, providing a live feed for the moderation team.

---

## User Reporting

As Flicko handles User-Generated Content (UGC), App Store / Play Store guidelines require an active reporting mechanism. Users can long-press any message or profile and tap "Report".

This makes a `POST /api/v1/reports` request. Reports are not sent to server moderators; they are sent to the global Flicko Trust & Safety admin interface (managed directly in the Supabase Dashboard by developers). Reports include the `target_id`, `message_id` (if applicable), and `reason` code.

---

## Related Documentation

- [Features: Bot System](bot-system.md) — How AutoMod integrates into the event bus
- [Security: Authorization](../security/authorization.md) — How the RBAC bits (like `BAN_MEMBERS`) are checked

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
