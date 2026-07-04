# Bots & Webhooks API

> **Reading time:** ~5 minutes · **Audience:** API Consumers · **Last Updated:** 2026-04-11

This reference covers programmatic integrations for a server. While Flicko currently embeds bots via an internal bus, server owners can configure generic incoming webhooks to pipe data from external systems (GitHub, Jira, etc.) directly into a channel.

---

## 1. Create a Webhook

Generates a new webhook URL tied to a specific channel.

**POST** `/api/v1/channels/{channel_id}/webhooks`

**Body:**
```json
{
  "name": "GitHub Actions Notifier",
  "avatar_url": "https://..." // Optional
}
```

**Response (201 Created):**
```json
{
  "id": "wh1...",
  "channel_id": "c1...",
  "token": "secure-random-token-string",
  "url": "https://api.flicko.app/api/v1/webhooks/wh1.../secure-random-token-string"
}
```
*Note: The generated `token` is only displayed once. If lost, the webhook must be deleted and recreated.*

---

## 2. Execute a Webhook

This is a public, unauthenticated endpoint (the authorization is the `token` in the URL path itself). Used by external systems to send messages.

**POST** `/api/v1/webhooks/{webhook_id}/{webhook_token}`

**Body:**
```json
{
  "content": "Deployment successfully completed on `main` branch.",
  "username_override": "GitHub CI" // Overrides the webhook name
}
```

**Response:** `204 No Content`

---

## 3. List Channel Webhooks

Returns all webhooks configured for a specific channel. Requires `MANAGE_WEBHOOKS` permission.

**GET** `/api/v1/channels/{channel_id}/webhooks`

**Response (200 OK):**
```json
[
  {
    "id": "wh1...",
    "name": "GitHub Actions Notifier",
    "avatar_url": null,
    "creator_id": "db3a2..." 
  }
]
```

---

## 4. Delete Webhook

Revokes the URL immediately. Any subsequent executions of that URL will return `401 Unauthorized`.

**DELETE** `/api/v1/webhooks/{webhook_id}`

**Response:** `204 No Content`

---

## Bot Setting Manipulation

Because Flicko's built-in bots are deeply integrated, their settings are exposed via standard REST paths accessible by users with `ADMINISTRATOR` privileges.

**PATCH** `/api/v1/servers/{server_id}/bot_settings/automod`

**Body:**
```json
{
  "filters": {
    "invite_blocker": { "enabled": true },
    "caps_spam": { "enabled": true, "threshold": 80 }
  }
}
```

See [Features: Bot System](../features/bot-system.md) for details on the settings schemas.

---

## Bot Integration Platform & Developer Portal

Flicko provides a modern Developer Portal API for building Discord-style bot applications. Every developer-registered Application owns exactly one bot user, which authenticates via a signed 3-segment token.

### 1. Developer Portal (Applications CRUD)

All Developer Portal endpoints require user authentication (standard Bearer JWT).

#### 1.1 Create an Application
Registers a new application. The platform automatically generates a unique `client_secret` (only returned once) and an Ed25519 keypair for signing interaction webhooks.

**POST** `/api/v1/applications`

**Request Body:**
```json
{
  "name": "Moderator Bot",
  "description": "Auto moderation and logging bot",
  "icon_url": "https://cdn.flicko.app/icons/modbot.png"
}
```

**Response (201 Created):**
```json
{
  "application": {
    "id": "e8a946b5-0c17-48f8-b3d9-601968846c98",
    "name": "Moderator Bot",
    "description": "Auto moderation and logging bot",
    "icon_url": "https://cdn.flicko.app/icons/modbot.png",
    "is_public": false,
    "is_active": true,
    "status": "active",
    "public_key": "8e3d64c12...",
    "metadata": {
      "private_key": "9e5c..."
    },
    "created_at": "2026-07-04T16:00:00Z",
    "updated_at": "2026-07-04T16:00:00Z"
  },
  "client_secret": "<CLIENT_SECRET>"
}
```

#### 1.2 List Applications
Returns a list of all applications owned by the authenticated user.

**GET** `/api/v1/applications`

**Response (200 OK):**
```json
[
  {
    "id": "e8a946b5-0c17-48f8-b3d9-601968846c98",
    "name": "Moderator Bot",
    "description": "Auto moderation and logging bot",
    "icon_url": "https://cdn.flicko.app/icons/modbot.png",
    "is_public": false,
    "is_active": true,
    "status": "active",
    "public_key": "8e3d64c12...",
    "created_at": "2026-07-04T16:00:00Z",
    "updated_at": "2026-07-04T16:00:00Z"
  }
]
```

#### 1.3 Get Application Details
Retrieves details for a specific application.

**GET** `/api/v1/applications/{id}`

**Response (200 OK):** (Same as the application object in 1.2)

#### 1.4 Update Application
Modifies application settings.

**PATCH** `/api/v1/applications/{id}`

**Request Body:**
```json
{
  "name": "Moderator Bot Pro",
  "is_public": true
}
```

**Response (200 OK):** (Returns the updated application object)

#### 1.5 Delete Application
Deletes the application and its associated bot user profile.

**DELETE** `/api/v1/applications/{id}`

**Response (204 No Content)**

---

### 2. Bot Token Auth & Rotation

#### 2.1 Reset/Rotate Bot Token
Generates a new signed bot token. Any previously issued tokens are instantly revoked. It also provisions or updates the corresponding bot user in the core database so that it can act as a standard participant on the platform.

**POST** `/api/v1/applications/{id}/bot/reset-token`

**Response (200 OK):**
```json
{
  "token": "v1.<BASE64_BOT_ID>.<BASE64_ISSUED_AT>.<HMAC_SIGNATURE>"
}
```

#### 2.2 Bot Authentication
To authenticate as a bot, make requests with the signed token using either the `Bot` or `Bearer` authorization scheme.

**Header:**
```http
Authorization: Bot v1.<BASE64_BOT_ID>.<BASE64_ISSUED_AT>.<HMAC_SIGNATURE>
```

#### 2.3 Token Format
Flicko bot tokens consist of four dot-separated segments designed for key rotation support and fast, stateless extraction:
`{key_version}.{base64(bot_user_id)}.{base64(issued_at)}.{hmac_signature}`

* **`key_version`**: Identifies which server-side signing secret was used. This enables zero-downtime key rotation.
* **`bot_user_id`**: Base64 encoded bot UUID. Can be decoded immediately for context initialization.
* **`issued_at`**: Unix timestamp (seconds since epoch) when the token was created.
* **`hmac_signature`**: HMAC-SHA256 signature of the preceding segments.

#### 2.4 Performance and Security
* **Sub-millisecond verification**: Token verification employs fast SHA-256 hashing.
* **Redis Caching**: Verification statuses are cached in Redis with a 5-minute TTL (`bot_token_valid:{hash}`), while negative results are cached for 1 minute to mitigate database hammering.

