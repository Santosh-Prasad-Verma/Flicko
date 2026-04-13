# Messages API

> **Reading time:** ~8 minutes · **Audience:** API Consumers · **Last Updated:** 2026-04-11

The Messages API powers all text chat logic in Flicko. These routes must handle the highest throughput in the system.

---

## 1. Fetch Message History

Retrieves historical messages using Cursor Pagination.

**GET** `/api/v1/channels/{channel_id}/messages?limit=50&before={message_uuid}`

- `limit`: defaults to 50, max 100.
- `before`: Fetches exactly 50 messages chronologically *older* than this UUID. 

**Response (200 OK):**
```json
[
  {
    "id": "m1...",
    "content": "Hello everyone!",
    "user_id": "u1...",
    "created_at": "2026-04-11T12:00:00Z",
    "attachments": [],
    "reactions": [
      { "emoji": "👍", "count": 3, "me": true }
    ],
    "user": {
      "username": "tarun",
      "avatar_url": "..."
    }
  }
]
```

---

## 2. Send Message

Asynchronously queues a message in the `msg-service` Batcher. Requires `SEND_MESSAGES` permission (and `ATTACH_FILES` if attachments are present).

**POST** `/api/v1/channels/{channel_id}/messages`

**Body:**
```json
{
  "content": "Look at my new cat!",
  "reply_to_id": "m2...", // Optional replying feature
  "attachments": [
    { "url": "https://...", "type": "image/jpeg", "width": 800, "height": 600 }
  ]
}
```

**Response (201 Created):** Returns Hydrated Message Object.

---

## 3. Edit Message

Modifies a message. You can only edit your own messages. The `edited_at` field will be automatically hydrated by Postgres.

**PATCH** `/api/v1/channels/{channel_id}/messages/{message_id}`

**Body:**
```json
{
  "content": "Typo fixed!"
}
```

---

## 4. Delete Message

Soft-deletes a message. Can be performed by the author OR by a moderator possessing the `MANAGE_MESSAGES` bit.

**DELETE** `/api/v1/channels/{channel_id}/messages/{message_id}`

**Response:** `204 No Content`

---

## 5. Add/Remove Reactions

Toggles an emoji reaction on a message. Reacting fires a `REACTION_ADD/REMOVE` WebSocket event.

**PUT** `/api/v1/channels/{channel_id}/messages/{message_id}/reactions/{emoji}`
Adds your reaction. Note: URL-encode the emoji (e.g. `%F0%9F%91%8D` for 👍).

**DELETE** `/api/v1/channels/{channel_id}/messages/{message_id}/reactions/{emoji}`
Removes your reaction.

---

## 6. Global Search

Full text search powered by PostgreSQL `tsvector`. Returns matching messages across all channels where the user possesses `VIEW_CHANNEL`.

**GET** `/api/v1/servers/{server_id}/search?q=query+string+here`

**Response (200 OK):**
```json
{
  "matches": [
    { "id": "m1...", "content": "...query string here..." }
  ]
}
```
