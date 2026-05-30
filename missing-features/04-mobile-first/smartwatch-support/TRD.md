# Smartwatch Support - TRD

## 1. Architecture Overview

```
                    ┌────────────────────────────────────────┐
                    │           Flicko Backend (Go)          │
                    │  /api/v1/notifications  /api/v1/react  │
                    │  /api/v1/transcribe (fallback)         │
                    └──────────────────┬─────────────────────┘
                                       │ HTTPS / WSS (FCM, APNs)
                                       │
                       ┌───────────────┴────────────────┐
                       │                                │
                       ▼                                ▼
            ┌──────────────────┐             ┌──────────────────┐
            │  Phone (Flutter) │             │  Phone (Flutter) │
            │   Android        │             │   iOS            │
            │                  │             │                  │
            │  FCM listener    │             │  APNs listener   │
            │  Wearable Data   │             │  WatchConnectivity│
            │   Layer client   │             │   session        │
            └────────┬─────────┘             └─────────┬────────┘
                     │ DataClient.putDataItem            │ updateApplicationContext / sendMessage
                     ▼                                   ▼
           ┌───────────────────┐                ┌──────────────────┐
           │  WearOS Module    │                │ watchOS Extension│
           │  (Kotlin/Compose) │                │ (Swift/SwiftUI)  │
           │                   │                │                  │
           │  Tiles, complica- │                │ Complications,   │
           │  tions, app activ-│                │ widgets, app     │
           │  ity, notifications│               │ scene, notifications│
           └───────────────────┘                └──────────────────┘
```

The watch never talks to the backend directly in v1. All traffic is proxied through the paired phone via the platform data layer. This keeps auth simple and leverages the phone's existing token refresh.

## 2. Components

### 2.1 Phone Side (Flutter)
- `WatchBridgeService` - Dart layer wrapping platform channels.
- Method channel `io.flicko/watch_bridge` for outgoing messages.
- Event channel `io.flicko/watch_events` for incoming taps and replies.

### 2.2 Phone Native (Android)
- `WatchBridgeModule.kt` - uses `Wearable.getDataClient()` and `Wearable.getMessageClient()`.
- Listens to `WearableListenerService` overrides for incoming `/reply`, `/react`, `/mark-read`.

### 2.3 Phone Native (iOS)
- `WatchBridge.swift` - `WCSession.default` delegate.
- Handles `didReceiveMessage` for incoming actions, `transferUserInfo` for outbound digests.

### 2.4 WearOS Module (`mobile/android/wear/`)
- Compose-for-Wear app. Single Activity hosts SwipeDismissNavigation.
- `FlickoNotificationListener` extends `NotificationListenerService` (mirroring phone notifications via Bridger).
- `FlickoTileService` - one tile per server (up to 3 active).

### 2.5 watchOS Extension (`mobile/ios/Watch/`)
- WatchKit App + WidgetKit (complications).
- `FlickoApp.swift` - `@main` SwiftUI App.
- Complications: `circularSmall`, `rectangular`, `accessoryCorner`.

## 3. Data Layer Contracts

### 3.1 Outbound (Phone -> Watch)

```json
// path: /digest
{
  "version": 1,
  "generatedAt": "2026-05-29T10:32:00Z",
  "servers": [
    { "id": "srv_abc", "name": "Flicko HQ", "unread": 12, "icon": "...base64..." },
    { "id": "srv_def", "name": "Friends",   "unread": 3,  "icon": "..." }
  ],
  "voice": { "active": true, "channelId": "ch_voice_42", "channelName": "general-voice" }
}
```

```json
// path: /notification
{
  "id": "msg_42",
  "channelId": "ch_xyz",
  "channelName": "#general",
  "author": { "name": "Riya", "avatarB64": "..." },
  "body": "are we still on for 4pm?",
  "preview": [ "Yes!", "Bring snacks" ],
  "ts": "2026-05-29T10:31:54Z",
  "actions": ["reply", "react", "mark_read", "mute_30m"]
}
```

### 3.2 Inbound (Watch -> Phone)

```json
// path: /reply
{ "messageId": "msg_42", "channelId": "ch_xyz", "kind": "voice|text|emoji",
  "text": "on my way", "audioB64": null, "lang": "en" }
```

```json
// path: /react
{ "messageId": "msg_42", "emoji": "👍" }
```

```json
// path: /mark-read
{ "channelId": "ch_xyz", "upTo": "msg_42" }
```

## 4. REST/WS Surface

No new public endpoints. The watch reuses the phone's existing flows. Two backend endpoints get a small extension:

### `POST /api/v1/messages`
Accepts an optional `client_origin: "watch"` header for analytics segmentation.

### `POST /api/v1/transcribe` (already used by voice-message-transcription feature)
The phone forwards a watch-recorded audio blob here when on-device Whisper is unavailable (e.g., older phones).

## 5. Background Wake Triggers

| Event                  | Android (WearOS)                          | iOS (watchOS)                         |
|------------------------|-------------------------------------------|---------------------------------------|
| New message            | `MessagingService.onMessageReceived` -> bridge | APNs to phone -> `WCSession.transferUserInfo` |
| User in voice channel  | Foreground service on phone -> tile update | Live Activity on phone -> complication update |
| Tile/complication tick | `TileService.onTileRequest`               | `getTimeline` reload every 15 min     |

## 6. NFRs

| Property             | Target                                                               |
|----------------------|----------------------------------------------------------------------|
| Wake-to-render       | < 800 ms p50, < 1.4 s p95                                            |
| Reply RTT (text)     | < 1.2 s from tap-send to phone-confirmed                             |
| Reply RTT (voice)    | < 4 s end-to-end including Whisper on phone                          |
| Battery (watch)      | < 4% additional daily drain at 50 notifications                       |
| Crash-free sessions  | 99.4%                                                                |
| Pair-to-onboard      | < 30 s from watch app first-launch to digest visible                 |
| Offline behavior     | Last digest visible; new actions queued and replayed when reconnected|
| Localization         | Inherits phone locale; v1 ships en, hi, es, fr, ja, pt-BR             |

## 7. Security

- All payloads piggyback on Wearable Data Layer / WatchConnectivity (encrypted at the OS level).
- No JWT stored on the watch. Auth lives on the phone.
- Voice audio recorded on watch is stored ephemerally in app caches and deleted after handoff.
- We add a rate limit of 60 outbound actions / minute / device on the phone bridge to mitigate runaway loops.

## 8. Observability

Telemetry events sent through existing `/api/v1/telemetry/event`:

- `watch.opened` - app cold launch
- `watch.notification.shown`
- `watch.notification.action` { action: reply|react|mark_read|mute }
- `watch.reply.sent` { kind, latency_ms }
- `watch.complication.refresh` { name, ttl_ms }
- `watch.error` { code, where }

Crashlytics for the watch process is enabled via Firebase. We tag stacktraces with `flavor=wearos` or `flavor=watchos` for filtering.

## 9. Failure Modes & Fallbacks

| Failure                         | Fallback                                                              |
|---------------------------------|-----------------------------------------------------------------------|
| Bluetooth disconnected          | Last digest visible, new replies queued; banner "queued, will send"   |
| Phone in DND                    | Notifications still arrive on watch (WearOS) but the phone respects DND for sound |
| Watch app process killed by OS  | Tile/complication serve stale cache up to TTL; cold launch on next tap |
| WCSession unreachable           | We retry via `transferUserInfo` (durable queue) instead of `sendMessage` |
| Whisper unavailable on phone    | Phone POSTs audio to `/api/v1/transcribe`                              |

## 10. Versioning

- Watch builds are tied to phone app build via shared `versionName`. The watch refuses messages with `version > self.version + 1` to avoid forward-incompat panics. Mismatch surfaces a "Update Flicko on phone" banner.
