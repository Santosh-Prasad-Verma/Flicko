# Voice & Video Channels

> **Reading time:** ~15 minutes · **Audience:** Backend, Mobile Developers · **Last Updated:** 2026-04-11

Flicko provides low-latency, high-quality audio and video channels using a Selective Forwarding Unit (SFU) architecture powered by LiveKit. This document explains how session state is synchronized between the database, WebSockets, and the LiveKit Cloud backend.

---

## Table of Contents

- [SFU Architecture](#sfu-architecture)
- [The Connection Lifecycle](#the-connection-lifecycle)
- [Voice State Management](#voice-state-management)
- [Permissions & Access Control](#permissions--access-control)
- [Mobile Implementation](#mobile-implementation)

---

## SFU Architecture

Rather than a Peer-to-Peer (P2P) mesh, which consumes exponential bandwidth as user counts increase (N * (N-1) connections), Flicko uses a Selective Forwarding Unit.

**How an SFU works:**
Every user uploads exactly **ONE** audio/video stream to the central LiveKit server. The server then forwards that stream to everyone else in the room. This means a user in a 10-person call is uploading 1 stream and downloading 9, rather than uploading 9 and downloading 9.

**LiveKit Cloud:** All heavy WebRTC lifting (codec negotiation, adaptive bitrate, TURN relays for restrictive NATs) is handled by LiveKit. Flicko's backend is only responsible for issuing authorization tokens and tracking who is in which room.

---

## The Connection Lifecycle

### 1. Token Generation (Backend)
When a user clicks "Join Voice", the app requests a token.
Route: `GET /api/v1/voice/token?channel_id={id}`

The `backend` service uses the LiveKit Go SDK to generate a JWT:
```go
import "github.com/livekit/protocol/auth"

func GenerateRoomToken(channelID, userID, username string) (string, error) {
    at := auth.NewAccessToken(config.LiveKitAPIKey, config.LiveKitAPISecret)
    grant := &auth.VideoGrant{
        RoomJoin: true,
        Room:     channelID, // Room name = Flicko channel ID
    }
    at.AddGrant(grant).
       SetIdentity(userID).
       SetName(username).
       SetValidFor(2 * time.Hour)
       
    return at.ToJWT()
}
```

### 2. State Synchronization (Database -> WebSocket)
Before returning the token, the backend records the user's state:
```sql
INSERT INTO voice_states (user_id, channel_id, session_id, self_mute, self_deaf)
VALUES ($1, $2, $3, false, false)
ON CONFLICT (user_id) DO UPDATE SET channel_id = $2;
```
It then broadcasts a `VOICE_STATE_UPDATE` to Redis. All connected clients receive this and update their UI to show the user's avatar appearing in the voice channel.

### 3. WebRTC Connection (Mobile)
The Flutter app receives the token and hands it to the LiveKit SDK, completely bypassing the Flicko backend for the actual audio traffic:
```typescript
import { LiveKitRoom } from '@livekit/react-native';

<LiveKitRoom 
  serverUrl={process.env.FLICKO_LIVEKIT_URL} 
  token={token} 
  connect={true}
>
  <RoomView />
</LiveKitRoom>
```

---

## Voice State Management

A user's "Voice State" determines what others see next to their name in the channel list (muted microphone icon, deafened headphones icon, sharing screen icon).

### State Mutability
When a user taps the "Mute" button on their phone:
1. The app mutes the local microphone hardware via LiveKit SDK.
2. The app sends a `PATCH /api/v1/voice/state` request to the backend.
3. The backend updates the database: `UPDATE voice_states SET self_mute = true`.
4. The backend broadcasts a `VOICE_STATE_UPDATE` via Redis.
5. All clients see the red mute icon appear next to the user.

### Disconnect Clean-up (Orphan Prevention)
If a user hard-closes the app, they never send a "Leave" request. To prevent ghost users lingering in voice channels forever:
1. LiveKit detects the WebSocket drop and triggers a webhook to `POST /api/v1/webhooks/livekit`.
2. The backend receives the `participant.disconnected` event from LiveKit.
3. The backend deletes the row from `voice_states`.
4. The backend broadcasts the disconnect event to all clients.

---

## Permissions & Access Control

Voice channels respect the Flicko 26-bit RBAC system. The Go backend checks these bits *before* issuing a LiveKit token:

- `CONNECT (0x1000)` — Required to get a token at all.
- `SPEAK (0x2000)` — If false, the LiveKit token is generated with `canPublish: false`, hard-muting them at the server level.
- `VIDEO (0x4000)` — If false, limits token to `canPublishData: false`.
- `MUTE_MEMBERS (0x8000)` — Allows a moderator to trigger a forced server mute on someone else.

---

## Mobile Implementation

The voice UI is driven by the `voiceStore.ts` Riverpod store, which combines local hardware state (from LiveKit hooks) with network state (from WebSocket `VOICE_STATE_UPDATE`s).

### Voice Activity Detection (VAD)
When a user speaks, their avatar gets a green glowing ring. We do not transmit audio volume levels over WebSockets; instead, the LiveKit SDK computes audio energy levels directly on the WebRTC stream and fires a local event:

```typescript
import { useTrackVolume } from '@livekit/react-native-components';

// Inside ParticipantCard component
const volume = useTrackVolume(audioTrack);
const isSpeaking = volume > 0.05;

return (
  <View style={[styles.avatarRing, isSpeaking && styles.speakingRing]}>
    <Avatar src={user.avatarUrl} />
  </View>
);
```

### Background Audio
The `app.json` contains native permissions enabling background audio playback and background microphone usage. A persistent OS notification is shown when connected to a voice channel, allowing the user to browse other apps while talking.

---

## Related Documentation

- [Features: Real-Time Messaging](real-time-messaging.md) — How the WebSockets work (used for state sync)
- [Architecture: Third-Party Integrations](../architecture/third-party-integrations.md) — LiveKit setup details

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
