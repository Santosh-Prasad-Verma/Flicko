# Channels API

> **Reading time:** ~7 minutes · **Audience:** API Consumers · **Last Updated:** 2026-04-11

Channels are the containers for messages and voice/video traffic. They must belong to a server.

---

## 1. List Server Channels

Fetches all channels in a server. The array must be sorted client-side based on `parent_id` (Categories) and `position`.

**GET** `/api/v1/servers/{server_id}/channels`

**Response (200 OK):**
```json
[
  {
    "id": "c1...",
    "server_id": "s1...",
    "name": "general",
    "type": "text",
    "parent_id": null,
    "position": 0,
    "is_nsfw": false,
    "permission_overwrites": []
  },
  {
    "id": "c2...",
    "name": "Game Lounge",
    "type": "voice",
    "parent_id": "category1...",
    "position": 1
  }
]
```

---

## 2. Create Channel

Creates a new channel in the server. Requires `MANAGE_CHANNELS` permission.

**POST** `/api/v1/servers/{server_id}/channels`

**Body:**
```json
{
  "name": "rules",
  "type": "text", 
  "parent_id": "category-uuid", // Optional
  "permission_overwrites": [
    {
      "target_id": "role-everyone-uuid",
      "target_type": "role",
      "allow_bits": 1, // VIEW_CHANNEL
      "deny_bits": 2   // SEND_MESSAGES
    }
  ]
}
```

**Response (201 Created):** Returns Hydrated Channel Object.

---

## 3. Update Channel Settings

Renames a channel or modifies its NSFW status/description. Requires `MANAGE_CHANNELS`.

**PATCH** `/api/v1/channels/{channel_id}`

**Body:**
```json
{
  "name": "announcements-new",
  "topic": "Read the rules here",
  "is_nsfw": false
}
```

---

## 4. Reorder Channels

Updates the `position` integer of multiple channels in a single transaction. Used heavily by drag-and-drop UI. Requires `MANAGE_CHANNELS`.

**PUT** `/api/v1/servers/{server_id}/channels/positions`

**Body:**
```json
{
  "positions": [
    { "channel_id": "c1...", "position": 0 },
    { "channel_id": "c2...", "position": 1 }
  ]
}
```

**Response:** `204 No Content`
