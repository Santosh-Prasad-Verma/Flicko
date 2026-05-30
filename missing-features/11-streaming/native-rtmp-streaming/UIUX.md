# Native RTMP Streaming — UI/UX Design

## 1. Design Principles

- Treat the channel as the streamer's home. The stream view replaces the voice-call UI when a track is published — it never opens a separate route.
- Reveal the stream key once. After that the UI shows only the prefix and a "rotate" button; this trains a healthy security habit.
- The viewer experience must feel as immediate as a Twitch click — under 3 seconds from tap to first frame on a 4G connection.
- Match Flicko's existing dark / light theme tokens (see `mobile/lib/core/theme/`) and reuse the voice-channel control bar shape so the muscle memory transfers.

## 2. Information Architecture

- Entry points (3): channel header "Go Live" affordance, server settings → Streaming, deep link `flicko://stream/<id>`.
- Parent navigation: voice / stage channel screen.
- Deep links: `flicko://stream/<id>`, `flicko://channel/<id>/setup-stream`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Stream Setup Sheet | Reveal ingest URL + key, pick region, start | empty, generating, ready, rotated |
| 2 | Stream View (viewer) | Watch live + chat overlay + donation alerts | loading, live, paused, ended, errored |
| 3 | Stream View (broadcaster) | Self-monitor + bitrate + viewer count | live, dropped-frames, error |
| 4 | Stream History | Past streams list, links to VOD if saved | empty, list |
| 5 | Server Streaming Settings | Toggle, quotas, allowed regions | default |

## 4. Wireframes (ASCII)

### Screen 1 — Stream Setup Sheet (broadcaster, just tapped Go Live)

```
┌────────────────────────────────────────────────┐
│ ←   Go Live in #after-hours                ⋯  │
├────────────────────────────────────────────────┤
│  Ingest region                                 │
│  ┌───────────────┐ ┌───────────────┐           │
│  │ ●  EU West    │ │    US East    │           │
│  └───────────────┘ └───────────────┘           │
│  ┌───────────────┐ ┌───────────────┐           │
│  │    Asia SE    │ │    SA East    │           │
│  └───────────────┘ └───────────────┘           │
│                                                │
│  Ingest URL                                    │
│  ┌───────────────────────────────────────┐ ┌─┐│
│  │ rtmps://ingest-eu1.flicko.app/live    │ │📋││
│  └───────────────────────────────────────┘ └─┘│
│                                                │
│  Stream key  (reveal once, then rotate)        │
│  ┌───────────────────────────────────────┐ ┌─┐│
│  │ fk_live_J5x2-•••••••••••••••••••••••• │ │👁││
│  └───────────────────────────────────────┘ └─┘│
│                                                │
│  Title (optional)                              │
│  ┌───────────────────────────────────────┐    │
│  │ Late-night Helldivers                 │    │
│  └───────────────────────────────────────┘    │
│                                                │
│  ┌───────────────────────────────────────────┐│
│  │  Open OBS guide          Rotate key       ││
│  └───────────────────────────────────────────┘│
├────────────────────────────────────────────────┤
│                              ●  I'm streaming  │
└────────────────────────────────────────────────┘
```

### Screen 2 — Stream View (viewer, live)

```
┌────────────────────────────────────────────────┐
│  ← #after-hours                            ⋯  │
├────────────────────────────────────────────────┤
│ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
│ ┃                                            ┃ │
│ ┃               [video frame]                ┃ │
│ ┃                                            ┃ │
│ ┃ ●LIVE  124 watching  720p60      [⛶]  [HD] ┃ │
│ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
│  Maya · Late-night Helldivers                  │
│  Followers 2.1k                  [Follow]      │
├────────────────────────────────────────────────┤
│  Chat                                          │
│  ─────────────────────────────────────────     │
│  zane: lets goooo                              │
│  jules: gg                                     │
│  ☆ kazi tipped 5 ⚡                            │
│                                                │
│  ┌───────────────────────────────────────┐ ┌─┐│
│  │ Say something...                      │ │↑││
│  └───────────────────────────────────────┘ └─┘│
└────────────────────────────────────────────────┘
```

### Screen 3 — Stream View (broadcaster, live)

```
┌────────────────────────────────────────────────┐
│  ← Streaming · 00:42:13                        │
├────────────────────────────────────────────────┤
│ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
│ ┃           [self preview, muted]            ┃ │
│ ┃ ●LIVE  124 watching  4500 kbps  720p60     ┃ │
│ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
│                                                │
│  Health: ● Stable        Dropped frames: 0.2%  │
│  Bitrate ▁▂▂▃▃▄▄▄▅▅▆▆▇▇█▇▆▆▅▅▄▄▄▃▃           │
│                                                │
│  Quick actions                                 │
│  [ Edit title ]  [ Rotate key ]  [ End stream ]│
└────────────────────────────────────────────────┘
```

### Screen 4 — Errored state

```
┌────────────────────────────────────────────────┐
│  We lost the feed                              │
│                                                │
│  ⚠ Encoder disconnected 9 s ago                │
│                                                │
│  Trying to reconnect…  ●●○○                    │
│                                                │
│  [ Force end stream ]   [ Open guide ]         │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `<StreamSetupSheet>`
- Props: `channelId`, `currentRegion`, `onStart()`.
- States: idle / generating / ready / rotating.
- Tokens: `colorScheme.surface`, `textTheme.bodyLarge`.

### `<StreamPlayer>`
- Wraps LiveKit SFU first; falls back to `better_player` HLS after 1.5 s without first frame.
- Props: `streamId`, `quality` (auto/manual), `onClipPressed`.

### `<LiveBadge>`
- Static red dot + "LIVE" label, pulses 1.4 s; `Semantics(label: "Live now")`.

## 6. Empty / Error / Loading

- **Empty (history):** illustration of a muted spotlight + "No streams yet — tap Go Live to start." CTA opens the setup sheet.
- **Loading:** skeleton with 16:9 placeholder, 3 chat-line shimmers, no "LIVE" badge.
- **Error:** inline banner only; never blocks the player; auto-dismisses on recover.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title (setup) | Go Live in #{channel} |
| CTA (setup) | I'm streaming |
| Empty (history) | No streams yet — tap Go Live to start |
| Error (encoder gone) | We lost the feed. Hang tight while we reconnect |
| Tooltip (rotate) | Rotating invalidates the current key immediately |

Voice: friendly, concise, second person, no jargon. Avoid "encoder" in user-facing copy where "feed" works.

## 8. Motion

- Player loading shimmer: 800 ms loop, opacity 0.4–0.8.
- Live badge pulse: 1.4 s ease-in-out; replaced by static red square under reduced-motion.
- Setup sheet transition: bottom sheet, 280 ms `Curves.easeOutCubic`.

## 9. Accessibility

- All player controls reachable via D-pad; Enter / Space toggles play.
- Colour contrast on the live badge: 4.6:1 over the darkest video frame (verified with luminance overlay).
- Captions toggle in player respects system caption settings.
- VoiceOver announces "Stream started, 124 watching" on state change via live region.

## 10. Responsive

- Phone portrait: 16:9 player pinned top, chat fills below.
- Phone landscape: full-screen player, chat as side rail (320 dp).
- Tablet / web: player + chat side-by-side, breakpoint 840.
- Foldable inner: place chat in the secondary panel automatically.

## 11. Theming

- Light, dark, AMOLED.
- Honour server accent for "Follow" CTA fill — falls back to brand teal.
- Live badge red is a fixed token so it remains recognisable across themes.
