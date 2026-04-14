# WebSocket Event Schemas (v1)

This document defines the **versioned WS event contract** for:

- `MESSAGE_*`
- `VOICE_*`
- `ACTIVITY_*`
- `MOD_*`

Contract rollouts are tracked in `schema_versions` (`domain`, `schema_type`, `version`, `status`).

## Envelope (all dispatch events)

All WS dispatch frames use the shared envelope from `services/shared/protocol/message.go`:

```json
{
  "op": 0,
  "t": "EVENT_NAME",
  "s": 123,
  "d": { "..." : "payload" }
}
```

- `op`: opcode (`0` = dispatch)
- `t`: event type
- `s`: sequence number
- `d`: event payload

## Version Matrix

| Domain | Version | Status |
|--------|---------|--------|
| MESSAGE | v1 | active |
| VOICE | v1 | active |
| ACTIVITY | v1 | active |
| MOD | v1 | active |

## MESSAGE_* (v1)

### MESSAGE_CREATE

Payload shape aligns with `protocol.MessagePayload`:

```json
{
  "id": "01H...",
  "channel_id": "uuid",
  "author_id": "uuid",
  "content": "hello",
  "nonce": "client-nonce",
  "timestamp": 1730000000000,
  "attachments": [
    {
      "id": "att-1",
      "filename": "file.png",
      "content_type": "image/png",
      "size": 12345,
      "url": "https://..."
    }
  ]
}
```

### MESSAGE_UPDATE

```json
{
  "id": "01H...",
  "channel_id": "uuid",
  "content": "edited content",
  "edited_at": "2026-04-14T20:00:00Z"
}
```

### MESSAGE_DELETE

```json
{
  "id": "01H...",
  "channel_id": "uuid",
  "deleted_at": "2026-04-14T20:00:00Z"
}
```

## VOICE_* (v1)

### VOICE_JOIN

```json
{
  "channel_id": "uuid",
  "user_id": "uuid",
  "joined_at": "2026-04-14T20:00:00Z"
}
```

### VOICE_LEAVE

```json
{
  "channel_id": "uuid",
  "user_id": "uuid",
  "left_at": "2026-04-14T20:05:00Z"
}
```

### VOICE_STATE_UPDATE

```json
{
  "user_id": "uuid",
  "channel_id": "uuid",
  "video_enabled": true,
  "screen_sharing": false,
  "camera_facing": "front",
  "video_quality": "high"
}
```

## ACTIVITY_* (v1)

### ACTIVITY_SESSION_UPDATE

```json
{
  "session_id": "uuid",
  "activity_id": "uuid",
  "channel_id": "uuid",
  "server_id": "uuid",
  "host_user_id": "uuid",
  "state": "launching",
  "started_at": "2026-04-14T20:00:00Z",
  "ended_at": null
}
```

### ACTIVITY_PARTICIPANT_UPDATE

```json
{
  "session_id": "uuid",
  "user_id": "uuid",
  "role": "participant",
  "event": "joined",
  "at": "2026-04-14T20:01:00Z"
}
```

### ACTIVITY_STATE_PATCH

```json
{
  "session_id": "uuid",
  "version": 12,
  "patch": {
    "leader_user_id": "uuid",
    "playhead_ms": 120000,
    "is_playing": true
  },
  "at": "2026-04-14T20:01:10Z"
}
```

## MOD_* (v1)

### MOD_ACTION

```json
{
  "server_id": "uuid",
  "target_user_id": "uuid",
  "actor_user_id": "uuid",
  "action": "ban",
  "reason": "spam",
  "duration_ms": null,
  "at": "2026-04-14T20:02:00Z"
}
```

## Compatibility Rules

- Additive fields are backward-compatible.
- Field removals/renames require a new major version.
- New event names in an existing domain require at least a minor version bump.
- Rollout status must be updated in `schema_versions`.
