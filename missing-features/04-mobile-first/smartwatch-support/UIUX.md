# Smartwatch Support - UIUX

## 1. Design Principles

- **1.5-second budget**: every screen must be readable and actionable inside one wrist-glance.
- **Thumb-only**: target sizes minimum 44pt (iOS) / 48dp (WearOS). No nested scrolling.
- **Glanceable typography**: Body 16pt, Caption 13pt. High contrast against AMOLED-friendly black.
- **Soft motion**: 200 ms ease-out for transitions; nothing parallax-y.
- **Honest staleness**: every screen footer surfaces "synced 2m ago" so the user trusts what they see.

## 2. Screen Inventory

1. Watch app launcher (digest)
2. Server detail (channels with unread)
3. Notification detail (the meat)
4. Reply chooser (text/voice/emoji)

## 3. Wireframes

### 3.1 Digest (App Launcher)

```
┌──────────── 41mm ──────────┐
│  Flicko          10:32     │
│  ─────────────────────────  │
│  [F]  Flicko HQ        12  │  <- tap to drill in
│  [V]  Voice • general-vc•  │  <- pulsing dot = active call
│  [F]  Friends           3  │
│  [F]  Side projects     1  │
│  ─────────────────────────  │
│  synced 2m ago    [refresh] │
└────────────────────────────┘
```

Copy:
- Title: "Flicko"
- Empty: "All caught up. Touch the crown to refresh."

### 3.2 Server Detail

```
┌────────────────────────────┐
│  Flicko HQ        ‹ back   │
│  ─────────────────────────  │
│  # general            8    │
│  # design             2    │
│  # eng-standup        1    │
│  @ Riya               1    │
│  ─────────────────────────  │
│  scroll · tap to open       │
└────────────────────────────┘
```

A11y: each row reads "channel general, eight unread, double tap to open".

### 3.3 Notification Detail

```
┌────────────────────────────┐
│  ‹  #general               │
│  ─────────────────────────  │
│  Riya                10:31  │
│  ┌──────────────────────┐  │
│  │ are we still on for  │  │
│  │ 4pm?                 │  │
│  └──────────────────────┘  │
│                            │
│  Last replies:             │
│   Yes!                     │
│   Bring snacks             │
│  ─────────────────────────  │
│  [ 💬 Reply ]   [ 😀 React] │
│  [ ✓ Read   ]   [ 🔕 Mute ] │
└────────────────────────────┘
```

Copy:
- Reply button: "Reply"
- React button: "React"
- Read: "Mark read"
- Mute: "Mute 30 min"

Voice over reads message body, then "four actions, swipe to choose".

### 3.4 Reply Chooser

```
┌────────────────────────────┐
│  Reply to Riya             │
│  ─────────────────────────  │
│  ┌──────────────────────┐  │
│  │  🎤  Hold to dictate │  │
│  └──────────────────────┘  │
│  ─────────────────────────  │
│  Suggested:                │
│   • on my way              │
│   • give me 5              │
│   • can't right now        │
│  ─────────────────────────  │
│  Quick react:              │
│   👍  ❤️  😂  🎉  😢  🔥    │
└────────────────────────────┘
```

States:
- Idle: shows microphone CTA + suggestions.
- Recording: button turns red, waveform replaces label.
- Transcribing: shimmering "Hearing you out..." text.
- Confirming: shows transcript + Send / Re-record.
- Failure: "Couldn't hear that. Try once more?" with one-tap retry.

## 4. Complications & Tiles

### 4.1 watchOS Corner Complication

```
┌──── circular ────┐
│       12         │
│      Flicko      │
└──────────────────┘
```

Tap opens the digest. If active voice, the number is replaced by a green dot.

### 4.2 watchOS Rectangular Complication

```
┌────────────────────┐
│ Flicko • 12 unread │
│ Riya: are we still │
│ on for 4pm?        │
└────────────────────┘
```

### 4.3 WearOS Tile

```
┌──── 192x192 ────┐
│ Flicko          │
│   12 unread     │
│   Voice: live   │
│   [open chat]   │
└─────────────────┘
```

## 5. Motion

- Notification arrival: 250 ms slide-up + haptic tick (`UNNotificationDefaultActionIdentifier` / `Vibrator.vibrate(50ms)`).
- Reply success: 600 ms checkmark draw + soft haptic.
- Recording: 1.0 s waveform pulse loop.
- Complication refresh: no animation; render-and-rest.

## 6. Haptics

| Event           | iOS (WKHapticType)   | WearOS                |
|-----------------|----------------------|-----------------------|
| Notification    | `notification`       | 50 ms vibrate         |
| Action success  | `success`            | 35 ms vibrate         |
| Action error    | `failure`            | 80 ms double pulse    |
| Recording start | `start`              | 30 ms                 |
| Recording stop  | `stop`               | 30 ms                 |

## 7. Accessibility

- All controls have `accessibilityLabel` / `contentDescription`.
- Dynamic Type supported on watchOS up to xxxLarge.
- WearOS supports system text scale via `LocalDensity` override.
- Color contrast >= 4.5:1 on dark theme. Light theme uses pure white background with 7:1 ratio for Body.
- Alternatives: every haptic is paired with a visible cue; every animation has a static fallback when `Reduce Motion` is on.
- Voice-over reads message body before metadata, mirroring iOS Mail's pattern.

## 8. Localization

Strings live in `mobile/lib/features/smartwatch_support/l10n/`. Watch surfaces re-export ARB strings via the bridge so we keep a single translation pipeline. Languages: en, hi, es, fr, ja, pt-BR for v1.

## 9. Theming

Watch theme mirrors phone theme but defaults to dark to save OLED battery. AMOLED-pure black `#000000` background; surfaces use `#0F0F11`; accent uses Flicko brand purple `#7B5BFF`.

## 10. Empty / Error Copy

- Empty digest: "All caught up. Touch the crown to refresh."
- Bluetooth lost: "Phone unreachable. Reply will send once reconnected."
- Voice mic denied: "Allow mic on your phone to dictate replies."
- Update mismatch: "Update Flicko on your phone to keep using the watch."
