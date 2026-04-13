# Bot API Endpoints
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Base URL
`/api/v1`

## Authentication Required
Yes — Bearer JWT + X-CSRF-Token

## Endpoints

### GET /commands
**Description:** List all available slash commands
**Success Response (200):**
```json
[{"name": "ban", "description": "Ban a member", "bot_name": "moderation"}]
```

### GET /commands/{serverId}
**Description:** List commands available in a specific server

### POST /commands/invoke
**Description:** Execute a slash command
**Request Body:**
```json
{"command_name": "ban", "server_id": "uuid", "channel_id": "uuid", "options": {"user": "<@uuid>", "reason": "spam"}}
```

### GET /servers/{serverId}/bots/{botName}/settings
**Description:** Get bot settings for a server

### PUT /servers/{serverId}/bots/{botName}/settings
**Description:** Update bot settings

### GET /servers/{serverId}/leaderboard
**Description:** Get XP leaderboard

### GET /servers/{serverId}/rank/{userId}
**Description:** Get a user's rank

### GET /servers/{serverId}/tickets
**Description:** List server tickets

### GET /servers/{serverId}/polls
**Description:** List active polls

### POST /polls/vote
**Description:** Vote on a poll

### GET /servers/{serverId}/starboard
**Description:** List starboard entries

### POST /servers/{serverId}/members/join-notify
**Description:** Trigger welcome bot for member join

### POST /servers/{serverId}/members/leave-notify
**Description:** Trigger goodbye message for member leave

### POST /messages/notify
**Description:** Trigger automod + leveling on message create

### POST /reactions/add-notify
**Description:** Trigger starboard on reaction add

### POST /reactions/remove-notify
**Description:** Trigger starboard on reaction remove
