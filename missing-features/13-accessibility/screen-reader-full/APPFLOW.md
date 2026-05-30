# Screen Reader Full Support — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as User (TalkBack on)
    participant OS as Android/iOS A11y
    participant M as Flutter App
    participant SR as Screen Reader provider
    participant LR as LiveRegion controller
    participant API as Go Backend
    participant RT as Centrifugo

    U->>OS: enables TalkBack
    OS->>M: AccessibleNavigation = true
    M->>SR: detect AT, set verbose=true (default)
    SR->>M: rebuild scaffolds with landmark roles
    U->>M: opens server "Study Group"
    M->>SR: announce("Study Group, 5 channels, 12 members online")
    SR->>OS: SemanticsService.announce(polite)
    OS-->>U: speaks announcement
    U->>M: taps channel "general"
    M->>API: GET /channels/:id/messages
    API-->>M: 200 {messages...}
    M->>SR: focus moves to first message; announce("general channel, 38 messages")
    RT-->>M: chat.message.created event
    M->>LR: push("New message from Asha: Hi everyone")
    LR->>SR: assertive announce
    SR->>OS: SemanticsService.announce(assertive)
    OS-->>U: speaks new message
```

## 2. State Machine

```
[idle]
   │ AT detected by MediaQuery.accessibleNavigation
   ▼
[a11y-ready]
   │ user toggles verbose off
   ▼
[a11y-quiet] -- toggle on --> [a11y-ready]

[a11y-ready]
   │ live region message arrives
   ▼
[announcing]
   │ SemanticsService.announce completes
   ▼
[a11y-ready]
```

## 3. User Journeys

### J1 — Happy path: blind user catches up on a server
1. Asha opens Flicko with TalkBack already on.
2. The home screen announces "Flicko, banner. 3 servers, navigation".
3. She swipes right to "Study Group, button".
4. Activates → "Study Group, 5 channels, main".
5. Swipes to channel "general, 12 unread, button".
6. Activates → "general, header. 12 new messages."
7. The first unread message bubble reads "Asha 09:14 AM, Hi everyone, welcome back".
8. A new message arrives. The live region announces "Aman: Just shared the slides".
9. Asha activates the reply button → focus moves to input → "Reply to Aman, edit text".

### J2 — Error path: telemetry endpoint unreachable
1. App starts in airplane mode, queues telemetry events locally.
2. On reconnect, batch-flushes via existing analytics pipeline.
3. No user-visible impact.

### J3 — First-time empty state: user with no AT
1. New user opens Flicko without TalkBack.
2. `MediaQuery.accessibleNavigation` is false.
3. Verbose announcements remain OFF.
4. Settings page shows "Verbose announcements" preference but as opt-in toggle.
5. No live region overhead is registered (controller lazy-init).

### J4 — User manually enables verbose mode
1. Sighted user wants to test screen reader behavior.
2. Goes to Settings → Accessibility → toggles "Verbose announcements" ON.
3. PATCH /preferences saves the choice.
4. Provider rebuilds with verbose=true even though `accessibleNavigation` is false.
5. App now plays announcements through `SemanticsService.announce`.

## 4. Edge Cases

- **Offline:** verbose preference cached locally in Hive box `accessibility_prefs`, queued PATCH on reconnect.
- **AT toggled mid-session:** `MediaQuery` change triggers provider rebuild; landmark structure updates without app restart.
- **Modal sheet opens:** focus is trapped via `FocusScope.canRequestFocus`; on dismiss, focus returns to the originator (announcement: "dialog dismissed").
- **High-frequency live region (e.g. spammed messages):** debounce to one announcement per 600 ms; queue overflow is summarised ("3 new messages").
- **User joins a voice channel:** announcement "Joined voice channel General. 4 members. Mute is off."; mute toggle change announces new state.
- **Localization fallback:** if locale string missing, use English with `Locale('en')` semantics tag so reader switches voice.
- **Embedded WebView (e.g. OAuth):** annotate as "external content"; native reader takes over inside the WebView.

## 5. Background / Async

- Triggered by: client-side semantics tree changes only (no backend cron).
- Telemetry batch: every 60 s flush via existing analytics worker.
- Idempotency key: `accessibility:<user_id>:<surface>:<minute_bucket>`.
- Failure policy: drop after 3 retries (best effort).

## 6. Notifications

- This feature does not introduce push notifications; it changes how existing in-app events are *announced*.
- For new mentions: existing push notification deep-links → on open, an assertive announcement summarises why we landed on the screen.

## 7. Diagnostic Mode

In debug builds, a floating button (`A11yProbe`) overlays the screen and:
- Highlights any node missing a semantic label in red
- Logs traversal order on tap-and-hold
- Offers a "speak this" preview button per node

The probe is excluded from release builds via `kReleaseMode`.

## 8. Cross-Feature Interactions

- With **reduced-motion-mode**: announcements remain identical; only motion suppressed.
- With **captions-voice-video**: caption stream is _also_ pushed to live region for users with both reader on and captions enabled.
- With **high-contrast-mode**: focus rings remain prominent regardless of contrast theme; announcements unaffected.
- With **color-blind-mode**: no interaction.
- With **dyslexia-font**: when OpenDyslexic active, screen reader still uses raw text, not glyph-mapped variant.
