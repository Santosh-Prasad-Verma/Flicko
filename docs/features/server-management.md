# Server Management

> **Reading time:** ~15 minutes · **Audience:** Backend, Mobile Developers · **Last Updated:** 2026-04-11

This document covers everything related to managing a community on Flicko: the hierarchy of servers and channels, the 26-permission Role-Based Access Control (RBAC) system, and the invite engine.

---

## Table of Contents

- [Server Hierarchy](#server-hierarchy)
- [Channel Types & Positioning](#channel-types--positioning)
- [The Permission System (RBAC)](#the-permission-system-rbac)
- [Channel Overwrites](#channel-overwrites)
- [Server Templates](#server-templates)
- [Invite Engine](#invite-engine)

---

## Server Hierarchy

The core grouping in Flicko is the `servers` table (often internally referred to as Guilds, matching Discord terminology). 

A Server is the root entity. If a Server is deleted:
1. `channels` are CASCADE deleted.
2. `messages` are CASCADE deleted (via channels).
3. `roles` and `members` are CASCADE deleted.
4. All bot configuration tables (`mod_settings`, etc.) are CASCADE deleted.

**Ownership:**
Every server has exactly one `owner_id`. The owner bypasses ALL permission checks automatically within the Go backend middleware. Ownership can be transferred via `PATCH /api/v1/servers/{id}/transfer`.

---

## Channel Types & Positioning

Channels belong to exactly one server. Flicko supports 4 channel types enforced by a PostgreSQL `CHECK` constraint:

1. `text`: Standard chat channel.
2. `voice`: WebRTC LiveKit channel.
3. `announcement`: Read-only (by default) channel where messages can be broadcast to other servers (future feature).
4. `category`: Does not hold messages. Used to group text/voice channels.

### Hierarchy via `parent_id`
A channel can be placed inside a Category by setting its `parent_id` to the Category's UUID. A channel where `parent_id = null` sits at the top of the server list, uncategorized. Category channels themselves must have `parent_id = null` (no nested categories).

### Reordering (`position`)
Channels have an integer `position`. The mobile app renders channels ordered by `position ASC`.
When a user drags-and-drops a channel to reorder it, the mobile app sends a bulk update `PUT /api/v1/servers/{id}/channels/positions` with an array of ID/position pairs. The backend executes this inside a single SQL transaction to prevent position collisions.

---

## The Permission System (RBAC)

Flicko uses a strict Role-Based Access Control system using a 64-bit integer bitfield to represent 26 distinct permissions.

### Bitfield Architecture
Each permission is represented by a single bit.
- `VIEW_CHANNEL` = `1 << 0` (1)
- `SEND_MESSAGES` = `1 << 1` (2)
- `MANAGE_MESSAGES` = `1 << 6` (64)
- `ADMINISTRATOR` = `1 << 25` (33554432)

If a Role has `VIEW_CHANNEL` and `SEND_MESSAGES` enabled, its `permissions` field in the database is `3` (1 + 2).
If a user has three roles, their total permissions are calculated using a bitwise `OR` across all their roles: `role1 | role2 | role3`.

### Base Roles
When a server is created, a default `@everyone` role is generated and automatically assigned to all new members. Its default bitfield grants basic chat and voice capabilities but no administrative power.

---

## Channel Overwrites

Often, a server needs a private channel (e.g., `#admin-only`), or needs to make a channel read-only (e.g., `#rules`). This is achieved using the `permission_overwrites` table.

An overwrite can target either a Role or a specific User. It contains two columns:
- `allow_bits`: Permissions explicitly granted.
- `deny_bits`: Permissions explicitly stripped.

### Calculation Logic
When checking if a user can send a message in `#rules`, the backend processes permissions in this strict order:

1. **Owner Check:** If user is owner → Allow.
2. **Administrator Check:** If any user role has the `ADMINISTRATOR` bit → Allow.
3. **Base Perms:** Combine all user's role permissions (Bitwise `OR`).
4. **Role Overwrites:** Find overwrites for the user's roles on this channel.
   - Remove denied bits: `base = base & ~deny_bits`
   - Add allowed bits: `base = base | allow_bits`
5. **User Overwrites:** Find overwrites explicitly targeting this user on this channel.
   - Remove denied bits: `base = base & ~deny_bits`
   - Add allowed bits: `base = base | allow_bits`
6. **Final Check:** Does `(base & TARGET_PERM) == TARGET_PERM`?

If the final check is `False`, the Go middleware aborts the request and returns `403 Forbidden`.

---

## Server Templates

When creating a server, entering a template name (e.g., "gaming", "community", "friends") triggers the `backend` to instantly perform a bulk insert of templated channels and default roles, giving the user a fully functional server layout without manual configuration.

*Note: The actual template JSON definitions reside in Go code (`internal/services/server_template_data.go`), not the database, to ensure they remain version-controlled.*

---

## Invite Engine

Users join servers exclusively through Invite codes (e.g., `https://flicko.app/join/x7Y9aQ`).

### Table: `invites`
- `code`: 6-8 character random string (Base62).
- `server_id`: The destination server.
- `creator_id`: The user who generated it.
- `max_uses`: Integer. If 0, unlimited.
- `uses`: Current usage count.
- `expires_at`: Timestamp. If null, never expires.

### Resolution Flow
1. A user clicks an invite link.
2. The mobile app parses the code from the deep link URL.
3. The app makes `GET /api/v1/invites/{code}` to fetch server metadata (Name, Icon, Member count) without joining, to display the confirmation card.
4. The user taps "Accept".
5. App makes `POST /api/v1/invites/{code}`.
6. Backend verifies `uses < max_uses` and `expires_at > NOW()`.
7. Backend inserts a row into `members` mapping the user to the server.
8. Backend increments the `uses` counter. (If `uses == max_uses`, the invite row is deleted).
9. Backend publishes `MEMBER_JOIN` to Redis, triggering the Welcome bot.

---

## Server Discovery

Public servers can be discovered by users via the Discovery engine.

### Real-time Metrics
The discovery algorithm prioritizes active servers by calculating dynamic metrics:
- **Online Count**: Instead of using static member counts, the discovery API joins the `server_members` table with the `presence` table to count users currently marked as `online`.
- **Visibility**: Only servers with `is_public = true` are returned.

This ensures that the "Discover Servers" page reflects live community activity levels rather than just total population.

---

## Related Documentation

- [Features: Bot System](bot-system.md) — How the Welcome bot reacts to the Invite engine
- [Security: Authorization](../security/authorization.md) — Detailed Go middleware checking logic

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
