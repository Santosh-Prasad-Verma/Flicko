# Voice Message Transcription - UIUX

## 1. Design Principles

- **Read or listen, your choice**: never force one mode.
- **Sync without surprise**: highlight tracks audio, but doesn't yank scroll.
- **Honest uncertainty**: low-confidence words look subtly different.
- **Calm shimmer**: no spinning rings; transcripts populate gracefully.

## 2. Screen Inventory

1. Voice message bubble (collapsed)
2. Voice message expanded with full transcript
3. Voice message playback with synchronized highlight
4. Search results showing voice messages by transcript

## 3. Wireframes

### 3.1 Collapsed Voice Bubble (default state)

```
┌──────────────────────────────────────────┐
│  Riya  10:31                             │
│  ┌──────────────────────────────────┐   │
│  │  ▶  ▁▂▆▇▆▅▃▂▁▃▅▆▇▆ 0:14         │   │
│  │                                  │   │
│  │  "are we still on for 4pm? bring │   │
│  │   the demo notes if you can"     │   │
│  │                          [show]  │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

Notes:
- 2-line transcript preview always visible.
- Tap `[show]` to expand. Long-press = copy text.
- Waveform bars use accent color; current playback position highlights.

### 3.2 Expanded Bubble With Full Transcript

```
┌──────────────────────────────────────────┐
│  Riya  10:31                             │
│  ┌──────────────────────────────────┐   │
│  │  ▶  ▁▂▆▇▆▅▃▂▁▃▅▆▇▆ 0:14         │   │
│  │                                  │   │
│  │  "are we still on for 4pm?      │   │
│  │   bring the demo notes if you   │   │
│  │   can. and remind me to send    │   │
│  │   the slides too."              │   │
│  │                                  │   │
│  │  Transcribed on this device      │   │
│  │  ⓘ may be inaccurate    [copy]   │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

Footer copy:
- "Transcribed on this device" or "Transcribed on Flicko servers" depending on engine.
- Inaccuracy disclaimer is one-time tappable to learn more.

### 3.3 Playback With Synchronized Highlight

```
┌──────────────────────────────────────────┐
│  Riya  10:31                             │
│  ┌──────────────────────────────────┐   │
│  │  ⏸  ▁▂▆▇█▅▃▂▁▃▅▆▇▆ 0:08 / 0:14  │   │
│  │                                  │   │
│  │  "are we still on for [4pm]?     │   │
│  │                       ^^^         │   │
│  │   bring the demo notes if you   │   │
│  │   can. and remind me to send    │   │
│  │   the slides too."              │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

Behavior:
- Currently spoken word gets a soft highlight (background color + 8px rounded rect).
- Tap any word -> seek audio to that timestamp.
- If user scrolls, we stop auto-tracking until they tap "follow" pill.

### 3.4 Search Results Including Voice Notes

```
┌──────────────────────────────────────────┐
│  Search: "demo notes"             [×]    │
├──────────────────────────────────────────┤
│  💬 #general                              │
│      Riya  10:31  voice 0:14              │
│      "...bring the demo notes if you..."  │
│                                           │
│  💬 #design                               │
│      Asha  Yesterday  text                │
│      "Updated demo notes in Figma"        │
│                                           │
│  💬 #general                              │
│      Riya  Mon  voice 0:08                │
│      "...the demo notes are ready..."    │
└──────────────────────────────────────────┘
```

A voice-note hit is identifiable by the `voice 0:14` chip and the surrounding ellipsis context.

## 4. States

| State                | Visual                                                  |
|----------------------|---------------------------------------------------------|
| Awaiting transcript  | Two shimmer lines under waveform                        |
| First word arrived   | Words pop in with 80 ms cubic ease, no layout shift     |
| Completed            | Static transcript + footer                              |
| Low confidence       | Words with conf < 0.6 italicized + lighter text color   |
| Failure              | "Tap to retry" pill replaces footer                     |
| Server fallback used | Footer says "Transcribed on Flicko servers" + cloud glyph |

## 5. Motion

- Shimmer: 1.4 s linear loop, 30% opacity sweep.
- Word arrival: 80 ms cubic; staggered by 30 ms per word.
- Highlight track: 120 ms ease-in-out as the active word changes.
- Auto-scroll within transcript: 250 ms cubic; suppressed if user scrolled in last 2 s.
- Reduce Motion: shimmer becomes a static gray bar; word arrival skipped.

## 6. Copy

- Loading: "Listening..." (after 2 s; before then, just shimmer).
- Failed: "Couldn't transcribe. Tap to retry."
- Server fallback consent (one-time): "On-device transcription failed. Try with Flicko servers? Audio is processed and not stored."
- Long clip: "This is over 90 seconds. Use Flicko servers to transcribe? It's faster."
- Inaccuracy info: "Transcripts are best-effort. Words may be wrong, especially for accents and noisy audio."

## 7. Accessibility

- Screen reader announces "voice note from Riya, 14 seconds, transcript: ..."
- Keyboard: arrow keys move highlight, space toggles playback.
- Word-tap targets at least 44pt tall.
- Captions are required content for hard-of-hearing users; we surface "Settings -> Voice notes -> Always show transcript" to make them visible by default.
- Color contrast: highlight uses purple `#7B5BFF` at 30% opacity over text color guarantees 4.5:1.

## 8. Theming

- Light: text `#1B1B1F`, highlight `#7B5BFF` 20%.
- Dark: text `#EDEDF0`, highlight `#7B5BFF` 30%.
- AMOLED: pure black background, slightly brighter accent.

## 9. Localization

ARB strings under `mobile/lib/features/voice_message_transcription/l10n/`. UI strings translatable; transcripts are language-aware (auto-detect or user-selected). Right-to-left support for transcripts in Arabic and Hebrew (deferred to v2 but layout already RTL-safe).

## 10. Edge UI

- Code-switching: each segment can carry its own `lang`. We render normally without flagging.
- Empty audio (silent recording): show "Couldn't hear anything. Try recording again."
- Mid-transcript interrupt by user: stop playback, leave transcript intact.
- Multiple voice notes in same minute: each transcribes independently; queueing visible via tiny spinner on subsequent bubbles.

## 11. Settings Surface

```
┌─────────────────────────────────────────┐
│ ‹  Voice notes                          │
├─────────────────────────────────────────┤
│  Show transcript by default     [ ON  ] │
│  Engine                                  │
│   ◉ On-device (recommended)              │
│   ◯ Flicko servers (faster)              │
│   ◯ On-device, fall back to servers      │
│                                          │
│  Multilingual model         [download]  │
│   ggml-base.q5_1  ~150 MB                │
│                                          │
│  Privacy                                 │
│   Audio is processed and never stored.   │
│   Transcripts live only on your device   │
│   unless you sent the message.           │
└─────────────────────────────────────────┘
```

## 12. Onboarding

A single tooltip on the first received voice note:
"Tap show to read this. Flicko transcribes voice notes on this phone, privately."
