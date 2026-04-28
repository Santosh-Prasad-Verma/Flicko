# Flicko Bot Marketplace

Complete bot marketplace infrastructure enabling third-party developers to build and distribute bots for Flicko.

## Overview

The bot marketplace allows developers to:
- Register external bots with webhook endpoints
- Subscribe to specific event types
- Receive events via secure webhooks with HMAC signatures
- Use API keys to interact with Flicko API
- Track installation stats, webhook deliveries, and reviews

## Architecture

```
External Bot → Webhook URL ← Flicko Event System
     ↓
  Bot SDK (Go)
     ↓
Flicko REST API (with API Key)
```

## Database Schema

### Tables Created (Migration 095)

1. **external_bots** - Bot registry with metadata, webhook URL, permissions
2. **bot_api_keys** - API keys for bot authentication (bcrypt hashed)
3. **bot_installations** - Bot installations per server
4. **bot_event_subscriptions** - Event types each bot subscribes to
5. **bot_webhook_deliveries** - Delivery logs with retry tracking
6. **bot_stats** - Daily statistics (installs, commands, uptime)
7. **bot_reviews** - User reviews and ratings (1-5 stars)
8. **bot_commands** - Command registry for each bot

## API Endpoints

### Bot Registration

**POST /api/v1/bots**
```json
{
  "name": "My Awesome Bot",
  "description": "Does cool things",
  "webhook_url": "https://mybot.example.com/webhook",
  "permissions": 8,
  "categories": ["moderation", "utility"],
  "tags": ["fun", "games"]
}
```

Response:
```json
{
  "bot_id": "uuid",
  "webhook_secret": "hex-encoded-secret"
}
```

### Generate API Key

**POST /api/v1/bots/{botID}/keys**
```json
{
  "name": "Production Key",
  "scopes": ["messages.read", "messages.write"],
  "expires_at": "2025-12-31T23:59:59Z"
}
```

Response:
```json
{
  "api_key": "flicko_bot_abc123...",
  "warning": "Save this key securely. It will not be shown again."
}
```

### Subscribe to Events

**POST /api/v1/bots/{botID}/events**
```json
{
  "event_types": [
    "MESSAGE_CREATE",
    "MEMBER_JOIN",
    "REACTION_ADD"
  ]
}
```

### Install Bot

**POST /api/v1/bots/{botID}/install**
```json
{
  "server_id": "uuid",
  "permissions": 8,
  "config": {
    "prefix": "!",
    "language": "en"
  }
}
```

## Webhook Events

### Event Structure

```json
{
  "event_id": "uuid",
  "event_type": "MESSAGE_CREATE",
  "timestamp": "2024-01-15T10:30:00Z",
  "server_id": "uuid",
  "channel_id": "uuid",
  "user_id": "uuid",
  "data": {
    "message_id": "uuid",
    "content": "Hello world",
    "author_id": "uuid"
  }
}
```

### Webhook Headers

```
Content-Type: application/json
X-Flicko-Signature: hmac-sha256-hex
X-Flicko-Event: MESSAGE_CREATE
X-Flicko-Event-ID: uuid
User-Agent: Flicko-Webhook/1.0
```

### Signature Verification

```go
import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/hex"
)

func verifySignature(body []byte, signature, secret string) bool {
    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write(body)
    expected := hex.EncodeToString(mac.Sum(nil))
    return hmac.Equal([]byte(signature), []byte(expected))
}
```

### Retry Logic

- Max retries: 3
- Backoff: Exponential (1s, 2s, 4s)
- Success: HTTP 2xx status code
- All attempts logged in `bot_webhook_deliveries`

## Bot SDK (Go)

### Installation

```bash
go get github.com/flicko-org/flicko-backend/pkg/flickosdk
```

### Quick Start

```go
package main

import (
    "context"
    "log"
    "github.com/flicko-org/flicko-backend/pkg/flickosdk"
)

func main() {
    client := flickosdk.NewClient("flicko_bot_your_api_key", "")
    
    server := flickosdk.NewWebhookServer("your_webhook_secret", handleEvent)
    log.Fatal(server.Start(8080))
}

func handleEvent(event flickosdk.Event) error {
    ctx := context.Background()
    client := flickosdk.NewClient("your_api_key", "")
    
    if event.EventType == "MESSAGE_CREATE" {
        content := event.Data["content"].(string)
        if content == "!ping" {
            _, err := client.SendMessage(ctx, event.ChannelID, "Pong!")
            return err
        }
    }
    return nil
}
```

### SDK Methods

**Messages**
- `SendMessage(ctx, channelID, content)` - Send message
- `EditMessage(ctx, channelID, messageID, content)` - Edit message
- `DeleteMessage(ctx, channelID, messageID)` - Delete message
- `AddReaction(ctx, channelID, messageID, emoji)` - Add reaction

**Moderation**
- `BanMember(ctx, serverID, userID, reason)` - Ban member
- `KickMember(ctx, serverID, userID, reason)` - Kick member

**Info**
- `GetChannel(ctx, channelID)` - Get channel info
- `GetServer(ctx, serverID)` - Get server info

## Event Types

| Event Type | Description | Data Fields |
|------------|-------------|-------------|
| MESSAGE_CREATE | New message | message_id, content, author_id |
| MESSAGE_UPDATE | Message edited | message_id, content |
| MESSAGE_DELETE | Message deleted | message_id |
| MEMBER_JOIN | User joined server | user_id, username |
| MEMBER_LEAVE | User left server | user_id |
| MEMBER_BAN | User banned | user_id, moderator_id, reason |
| REACTION_ADD | Reaction added | message_id, emoji, user_id |
| REACTION_REMOVE | Reaction removed | message_id, emoji, user_id |
| CHANNEL_CREATE | Channel created | channel_id, name, type |
| ROLE_CREATE | Role created | role_id, name, permissions |
| VOICE_JOIN | User joined voice | channel_id, user_id |

## Security

### API Key Format
- Prefix: `flicko_bot_`
- Length: 64 hex characters
- Storage: bcrypt hashed
- Prefix stored for fast lookup

### Webhook Security
- HMAC-SHA256 signatures
- Secret per bot (32 bytes)
- Signature in `X-Flicko-Signature` header
- Constant-time comparison

### Permissions
- Bitfield system (same as Discord)
- Checked at API and database level
- Per-server installation permissions

## Statistics & Monitoring

### Daily Stats (bot_stats table)
- Server count
- Active users
- Command invocations
- Webhook success rate
- Average response time

### Webhook Delivery Logs
- Status code
- Response time (ms)
- Success/failure
- Error messages
- Retry count

## Example Bots

See `/examples/example-bot/` for a complete working example.

### Simple Command Bot
```go
if strings.HasPrefix(content, "!hello") {
    client.SendMessage(ctx, channelID, "Hello!")
}
```

### Welcome Bot
```go
if event.EventType == "MEMBER_JOIN" {
    username := event.Data["username"].(string)
    client.SendMessage(ctx, welcomeChannel, fmt.Sprintf("Welcome %s!", username))
}
```

## Deployment

### Bot Approval Process
1. Developer registers bot (status: `pending`)
2. Admin reviews bot (checks webhook URL, permissions)
3. Admin approves (status: `approved`) or rejects
4. Bot appears in marketplace

### Hosting Requirements
- Public HTTPS endpoint for webhooks
- Port 443 or custom port with reverse proxy
- SSL/TLS certificate
- Uptime monitoring recommended

## Rate Limits

- API requests: 50/second per bot
- Webhook delivery timeout: 10 seconds
- Max retries: 3 attempts
- Backoff: Exponential (1s, 2s, 4s)

## Best Practices

1. **Always verify webhook signatures**
2. **Respond to webhooks within 10 seconds**
3. **Use exponential backoff for API calls**
4. **Store bot config in database, not code**
5. **Log all errors for debugging**
6. **Handle rate limits gracefully**
7. **Use structured logging (JSON)**

## Troubleshooting

### Webhook not receiving events
- Check bot is installed on server
- Verify event subscriptions are enabled
- Check webhook URL is publicly accessible
- Verify HTTPS with valid certificate

### API key invalid
- Check key format: `flicko_bot_...`
- Verify key not revoked
- Check expiration date
- Ensure bot status is `approved`

### Signature verification fails
- Use exact webhook secret from registration
- Hash entire request body (raw bytes)
- Use constant-time comparison
- Check header name: `X-Flicko-Signature`

## Future Enhancements

- [ ] Bot categories and discovery
- [ ] Featured bots section
- [ ] Bot analytics dashboard
- [ ] Slash command registration
- [ ] Interactive components (buttons, selects)
- [ ] Bot permissions UI
- [ ] Webhook retry configuration
- [ ] Rate limit customization
- [ ] Multi-language SDK (Python, TypeScript)
