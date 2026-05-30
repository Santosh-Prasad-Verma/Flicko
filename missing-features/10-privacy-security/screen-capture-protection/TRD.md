# Screen Capture Protection — Technical Requirements

## 1. Architecture Overview

```
   ┌─────────────────────────┐
   │   Flicko Mobile         │
   │                         │
   │  ┌──────────────────┐   │
   │  │ ProtectedScope   │   │
   │  │  Widget          │   │
   │  └────────┬─────────┘   │
   │           │             │
   │   Android │             │
   │  ┌────────▼──────────┐  │
   │  │ flutter_window-   │  │
   │  │ manager (FLAG_    │  │
   │  │ SECURE on/off)    │  │
   │  └───────────────────┘  │
   │                         │
   │   iOS                   │
   │  ┌────────────────────┐ │
   │  │ MethodChannel →    │ │
   │  │ UIScreen.is        │ │
   │  │ Captured listener  │ │
   │  │ + scrim overlay    │ │
   │  └────────────────────┘ │
   └─────────────────────────┘
        │ realtime "I'm recording" events
        ▼
   ┌──────────────┐
   │ Centrifugo   │
   │ channel:<id> │
   │ event=record │
   └──────────────┘
```

## 2. Components

### Backend (Go)

- **Service:** `internal/services/privacy/screen_capture_protection/service.go`
- **Handler:** `internal/handlers/screen_capture_handler.go`
- **Models:** add `ScreenCaptureProtected bool` to channel and DM models
- **Repo:** patch `internal/repo/channels_repo.go` to read/write the flag

Lightweight backend — most work is client-side.

### Mobile (Flutter)

- **Feature folder:** `mobile/lib/features/privacy/screen_capture_protection/`
  - `application/`: `protectionScopeProvider`, `recordingStatusProvider`
  - `presentation/`: `ProtectedScope` (Widget), `RecordingBanner`, `RecordingScrim`
  - `platform/`: `screen_capture_channel.dart` (MethodChannel)
- **Native:**
  - `mobile/android/app/src/main/kotlin/.../ScreenCapturePlugin.kt` (FLAG_SECURE management)
  - `mobile/ios/Runner/ScreenCapturePlugin.swift` (UIScreen observer)

### Infra
- DB: Postgres — additive columns + permissions tracking.
- Realtime: Centrifugo events on channel.

## 3. API Contracts

### REST
```
PATCH /api/v1/channels/:id            { screen_capture_protected: bool }
PATCH /api/v1/dms/:id/protection      { screen_capture_protected: bool, requires_consent_from: [user_id] }
POST  /api/v1/dms/:id/protection/consent  user accepts
```

### WebSocket / Centrifugo
- Channel: `channel:<id>` or `dm:<id>`
- Events: `screen_capture.protection_changed`, `screen_capture.recording_started`, `screen_capture.recording_stopped` (iOS only)

### Payloads
```jsonc
// PATCH protection
{ "screen_capture_protected": true }

// recording event
{ "user_id": "uuid", "platform": "ios", "started_at": "..." }
```

## 4. Permissions & Auth

- Channel mods can flip protection on a channel.
- DMs require both-party consent — one toggles on, other receives a request to consent; protection only active when both have consented.
- "Recording" events are user-driven (the device that detected its own recording reports it). Server does not synthesize fake recording events.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| FLAG_SECURE attach latency (Android) | <50ms on screen entry |
| iOS recording-detection latency | <500ms (OS dependent) |
| Realtime recording-event delivery | <1s p99 |
| Battery overhead | <0.5%/hour active session |

## 6. Dependencies

- `flutter_windowmanager` ^0.2.0 (Android FLAG_SECURE).
- iOS native `UIScreen.captureDidChangeNotification`.
- Centrifugo for realtime.

## 7. Observability

- Metrics: `flicko_screen_capture_protection_attach_total{platform,scope}`, `flicko_screen_capture_recording_detected_total{platform}`.
- Logs: protection on/off transitions; recording events with user_id (in audit log).
- Alerts: protection failures (FLAG_SECURE attach exception) > 1% trigger investigation.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| FLAG_SECURE not honored on rooted Android | bypass | document; show banner in protected channels "we cannot enforce on rooted devices" |
| iOS recording-detection delay | user records few hundred ms before scrim | prefer scrim-up by default; minimize content rendering before observer attaches |
| Web client | flag does nothing | block protected content access from web; show "open in mobile" |
| MethodChannel error on iOS | scrim doesn't fire | fail-safe: if observer registration errors, refuse to render protected content |

## 9. Threat Model

**Attackers**
- A1: Recipient screenshotting on Android. Mitigation: `FLAG_SECURE`. Effective on stock Android; bypass on rooted devices.
- A2: Recipient screen-recording on iOS. Mitigation: detect via `UIScreen.isCaptured`; black-scrim immediately; notify counterparty.
- A3: Recipient using a second physical device (camera-of-screen). Mitigation: none possible; documented.
- A4: Recipient accessibility services exfiltrating text. Mitigation: out of scope; document limitation.
- A5: Adversary monkey-patching the Flicko APK to remove `FLAG_SECURE`. Mitigation: integrity check via Play Integrity / DeviceCheck warns counterparty.

**Assets**
- Sensitive channel content; ephemeral DM content.

**Limitations (in user-facing copy)**
- Phone camera can still photograph the screen.
- Rooted/jailbroken devices may bypass these protections.
- Web client cannot enforce; protected content is hidden there.
