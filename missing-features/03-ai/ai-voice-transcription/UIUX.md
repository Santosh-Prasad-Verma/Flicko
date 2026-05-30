# Live Voice Captions — Whisper.cpp Transcription — UI/UX Design

## 1. Design Principles

- Captions are an accessibility surface; default placement is the bottom of the voice screen, never overlapping the speaker grid avatars
- Latency feels low — partials show within 500ms (rolling), finals settle within 2s
- One line per utterance; speaker name uses the server-color of that user
- Customizable: font size, opacity, position (top/bottom)

## 2. Information Architecture

- **Entry points:**
  1. Voice channel screen — toggle "CC" in the top bar (visible if admin enabled)
  2. Voice channel settings (admin) — Captions ON/OFF
  3. Personal accessibility settings — "Captions defaults"
- **Deep links:** `flicko://channel/<id>/captions`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Captions overlay | Live transcript bottom panel | hidden, idle, streaming, error |
| 2 | Captions settings sheet | Font size, position, opacity | content |
| 3 | Channel admin toggle | Enable per channel | content |
| 4 | Late-join transcript modal | Last 5min on join | content |
| 5 | Session export | Post-session transcript download | content |

## 4. Wireframes (ASCII)

### Screen 1 — Captions overlay (bottom)

```
┌───────────────────────────────────────────────┐
│  #lounge — voice                          ⋯   │
│                                               │
│  ╔═════╗   ╔═════╗   ╔═════╗   ╔═════╗        │
│  ║alice║   ║bob  ║   ║carla║   ║dave ║        │
│  ╚══●══╝   ╚═════╝   ╚═════╝   ╚═════╝        │
│   speaking                                    │
│                                               │
│  ─────────────────────────────────────────    │
│  ┌─ captions ─────────────────────── CC ON ─┐ │
│  │ alice: did anyone see the keynote▌       │ │
│  │ bob:   yeah it was wild                  │ │
│  │ carla: link?                             │ │
│  └─────────────────── live · whisper-small ─┘ │
│                                               │
│ [ mic ]  [ video ]  [ screen ]  [ leave ]     │
└───────────────────────────────────────────────┘
```

### Screen 2 — Settings sheet

```
┌───────────────────────────────────────────────┐
│  Captions                              ✕      │
├───────────────────────────────────────────────┤
│  Show captions                       [ON]     │
│  Position    (•) bottom   ( ) top             │
│  Size        S   M   L   XL                   │
│  Opacity     ──●──────  85%                   │
│  Speaker color   [ON]   uses member color     │
│                                               │
│  Reduce profanity in captions      [OFF]      │
│                                               │
│  Language     auto                            │
│                                               │
│  Late join                                    │
│   show last 5 minutes when I join   [ON]      │
│                                               │
│  [   Reset   ]      [   Done   ]              │
└───────────────────────────────────────────────┘
```

### Screen 3 — Admin enable

```
┌───────────────────────────────────────────────┐
│ ← #lounge — Captions                          │
├───────────────────────────────────────────────┤
│ Enable live captions               [ON]       │
│ Model         (•) small.en (default)          │
│               ( ) tiny.en (low CPU)           │
│               ( ) small (multilingual)        │
│ Default language     auto                     │
│                                               │
│ Members can override visibility per session   │
└───────────────────────────────────────────────┘
```

### Screen 4 — Late-join modal

```
┌───────────────────────────────────────────────┐
│  Last 5 minutes                          ✕    │
├───────────────────────────────────────────────┤
│  alice: hey we're talking about the keynote   │
│  bob:   they showed the new vision pro        │
│  carla: link in chat                          │
│  dave:  haha yeah                             │
│  alice: anyway, where were we                 │
│         ────                                  │
│  [ jump to live ]                             │
└───────────────────────────────────────────────┘
```

### Screen 5 — Session export (after voice session ends)

```
┌───────────────────────────────────────────────┐
│  Session ended — 42 minutes                   │
│                                               │
│  Transcript                                   │
│  ┌─────────────────────────────────────────┐ │
│  │ 12:00 alice: kicking off                │ │
│  │ 12:02 bob:   re: the keynote…           │ │
│  │ ...                                     │ │
│  └─────────────────────────────────────────┘ │
│                                               │
│  [ download .txt ]   [ copy ]   [ delete ]    │
└───────────────────────────────────────────────┘
```

## 5. Component Specs

### `CaptionsOverlay`
- Props: `channelId`, `streamProvider`, `position`, `opacity`
- Renders rolling 4 lines; older fade out
- Bottom-anchored or top-anchored

### `CaptionLine`
- Props: `speakerName`, `speakerColor`, `text`, `isPartial`, `confidence`
- Partial state: italic + cursor blink
- Low-confidence (<0.6): subtle dotted underline

### `CaptionsSettingsSheet`
- Bottom sheet with sliders + radios; saves to user prefs

## 6. Empty / Error / Loading

- **Hidden:** when feature off or user toggled CC OFF
- **Idle:** "Waiting for someone to speak…" subtle gray placeholder
- **Error:** banner "Captions paused — reconnecting…"
- **Degraded:** badge "captions: tiny model — fast but rougher"

## 7. Copy

| Surface | Copy |
|---------|------|
| Toggle on | `CC ON` |
| Idle | `Waiting for someone to speak…` |
| Reconnecting | `Captions paused — reconnecting…` |
| Late-join | `Caught up. Jump to live?` |
| Export saved | `Transcript saved.` |

## 8. Motion

- Caption line append: slide up + fade 200ms, line 4 fades out
- Speaker color background: fade 120ms
- Reduced motion: instant snap

## 9. Accessibility

- Captions ARE the accessibility surface — must be ≥4.5:1 contrast
- Adjustable font size from 14sp to 28sp
- Live region announces every final caption (polite)
- Screen-reader users get the transcript directly via the existing `voice_transcripts` query (alternate flow)
- Color contrast respects high-contrast theme

## 10. Responsive

- Phone: bottom 4 lines, full width
- Tablet: side panel option (right rail) when in landscape
- Web: floating draggable panel
- Foldable: bottom of focused half

## 11. Theming

- Light + dark + AMOLED
- High-contrast mode: white-on-black force
- Per-server accent: borders only; text always WCAG-compliant default
