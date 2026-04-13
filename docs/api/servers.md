# Servers API

> **Reading time:** ~7 minutes · **Audience:** API Consumers · **Last Updated:** 2026-04-11

Servers (internally known as Guilds) are the root isolation container for communities. All channels, roles, and members belong to a server.

---

## 1. Get Current User's Servers

Returns an array of servers that the current user is a member of.

**GET** `/api/v1/users/@me/servers`

**Response (200 OK):**
```json
[
  {
    "id": "a1b2c3d4...",
    "name": "Flicko Dev Hub",
    "icon_url": "https://...",
    "owner_id": "db3a2b10...",
    "is_public": true
  }
]
```

---

## 2. Get Server Details

Fetches full metadata for a specific server. User must be a member or possess a valid invite.

**GET** `/api/v1/servers/{server_id}`

**Response (200 OK):**
```json
{
  "id": "a1b2c3d4...",
  "name": "Flicko Dev Hub",
  "icon_url": "https://...",
  "owner_id": "db3a2b10...",
  "system_messages_channel_id": "c98x...",
  "roles": [
    { "id": "role1", "name": "Admin", "permissions": "4294967295", "color": "#FF0000" }
  ],
  "bot_settings": {
    "automod": true,
    "welcome": true
  }
}
```

---

## 3. Create a Server

Creates a new server. The user making the request automatically becomes the `owner_id`. If they provide a `template`, default channels are instantly hydrated.

**POST** `/api/v1/servers`

**Body:**
```json
{
  "name": "My New Server",
  "icon_url": "https://...",
  "template": "community" // Optional. Valid: 'community', 'gaming', 'friends'
}
```

**Response (201 Created):** Returns Hydrated Server Object.

---

## 4. Delete a Server

Irreversibly deletes the server, cascading to all messages, channels, and members. Requires `owner_id` privileges.

**DELETE** `/api/v1/servers/{server_id}`

**Response:** `204 No Content`

---

## 5. Fetch Server Members

Fetches a paginated list of all members in the server.

**GET** `/api/v1/servers/{server_id}/members?limit=50&offset=0`

**Response (200 OK):**
```json
{
  "total_count": 102,
  "members": [
    {
      "user_id": "db3a2...",
      "username": "tarun",
      "roles": ["role1", "role2"],
      "joined_at": "2026-04-11T12:00:00Z" // Contextual to this server
    }
  ]
}
```

---

## 6. Update Server Roles

Adds or removes a role from a member. Requires `MANAGE_ROLES` permission, and the actor's top role must be hierarchically above the target role.

**PUT** `/api/v1/servers/{server_id}/members/{user_id}/roles/{role_id}`
Adds the role.

**DELETE** `/api/v1/servers/{server_id}/members/{user_id}/roles/{role_id}`
Removes the role.
