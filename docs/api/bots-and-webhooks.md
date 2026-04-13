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
