# Catch-Me-Up — AI Channel Summary — UI/UX Design

## 1. Design Principles

- The pill never blocks scroll — it floats above the unread separator and dismisses on first scroll up
- Bullets stream in **left-aligned** with a small ✦ glyph; each line settles before the next begins
- Citations are tap-to-jump scrollers; the destination message blinks once with `colorScheme.primary @ 0.2`
- "Less is more" — never more than 7 bullets; if more is needed, show "show 3 more" disclosure
- Match `ChannelMessagesScreen` chrome, no modal full-takeover

## 2. Information Architecture

- **Entry points:**
  1. Floating `✦ Catch me up` pill above the unread separator (auto-shown when ≥5 unread)
  2. Long-press any message → "Summarize from here"
  3. Channel header `⋯` → "Summarize last 24h"
- **Parent navigation:** lives inside `ChannelMessagesScreen`
- **Deep links:** `flicko://channel/<id>/summary?since=<ts>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Catch-me-up pill | CTA above unread separator | hidden, idle, loading, dismissed |
| 2 | Summary card (inline) | Streamed bullets above unread | streaming, done, error, refused, partial |
| 3 | Citation peek | Bottom sheet showing the 1-3 source messages | content |
| 4 | Daily digest (v2 stub) | Across-server card on Home | content |

## 4. Wireframes (ASCII)

### Screen 1 — Catch-me-up pill above unread separator

```
                    ──────  142 unread  ──────
                ╭────────────────────────────╮
                │  ✦  Catch me up   (24h) →  │
                ╰────────────────────────────╯
   alice  yesterday 9:14 PM
   hey did anyone see the keynote?
```

### Screen 2 — Summary card (streaming)

```
┌────────────────────────────────────────────────┐
│ ✦ Summary — last 24h, 142 messages             │
│ ───────────────────────────────────────────    │
│ • @alice and @bob shipped the v2 onboarding    │
│   flow [¹ ²]                                   │
│ • Discussion of the new theme system; pending  │
│   review by @carla [³]                         │
│ • Memes about Friday▌                          │
│ ───────────────────────────────────────────    │
│ participants: alice, bob, carla, david         │
│ vibe: focused                                  │
│ 👍  👎    streaming…                           │
└────────────────────────────────────────────────┘
```

### Screen 2b — Done state

```
┌────────────────────────────────────────────────┐
│ ✦ Summary — last 24h, 142 messages             │
│ ───────────────────────────────────────────    │
│ • @alice and @bob shipped v2 onboarding [¹ ²]  │
│ • Theme system pending review by @carla [³]    │
│ • Memes about Friday [⁴]                       │
│ • @david proposed a beach offsite              │
│ • #design got the new logo SVGs [⁵]            │
│ ───────────────────────────────────────────    │
│ participants: alice, bob, carla, david         │
│ vibe: focused        [ start reading from top ]│
│ 👍  👎  ✕ dismiss                              │
└────────────────────────────────────────────────┘
```

### Screen 3 — Citation peek

```
┌────────────────────────────────────────────────┐
│  Source messages                          ✕    │
├────────────────────────────────────────────────┤
│  alice  yesterday 9:14                         │
│  shipped the v2 onboarding to staging          │
│                                                │
│  bob  yesterday 9:18                           │
│  PR merged, deploy at 10                       │
│                                                │
│        [   Jump to thread   ]                  │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `CatchMeUpPill`
- Props: `unreadCount`, `windowDuration`, `onTap`
- States: hidden (no unread or <5), idle, loading (after tap), dismissed
- Token usage: `colorScheme.primaryContainer` background, `textTheme.labelLarge`
- Auto-hide: 8s after appearing if not tapped, or on scroll up gesture

### `SummaryCard`
- Props: `requestId`, `streamProvider`, `onCitationTap(msgId)`, `onFeedback(rating)`
- Streams bullets one at a time; each new bullet fades in 200ms
- Has `dismiss` ✕ that hides for this anchor (won't reappear until new unreads)

### `CitationChip`
- Inline `[¹]` superscript chip; `onTap` opens `CitationPeekSheet`

## 6. Empty / Error / Loading

- **Hidden:** no pill rendered when unread <5 or feature flag off
- **Loading:** pill shows shimmer text; card replaces it on first bullet
- **Error:** pill changes to `Try again` chip; card collapses
- **Refused (too few msgs):** card shows "Not enough activity to summarize. Just scroll up — there are only 4 messages."
- **Partial (>500 msgs):** banner "Summary covers the most recent 500 messages."

## 7. Copy

| Surface | Copy |
|---------|------|
| Pill (1d) | `✦ Catch me up — last 24h` |
| Pill (since visit) | `✦ Catch me up — 142 messages` |
| Loading | `Reading the channel…` |
| Done sentiment chip | `vibe: focused` |
| Refused | `Not enough activity. Scroll up — there are only 4 messages.` |
| Partial | `Showing the most recent 500 messages.` |
| Rate-limited | `Daily summary cap reached. Resets at midnight.` |
| Error | `Couldn't summarize right now. Try again.` |

Voice: friendly, concise. Never "AI" — just "summary".

## 8. Motion

- Pill enter: slide up + fade 250ms
- Bullet append: slide-in-up 12px + fade 180ms; staggered 80ms apart
- Citation tap → jump: target message blinks 1× (180ms in / 320ms out)
- Reduced motion: instant snap on bullet append

## 9. Accessibility

- Live region: `polite` on bullet append; "Summary updated, three bullets so far"
- Citation chips: `Semantics(label: 'source one of two, alice, yesterday at 9:14 PM')`
- Tap targets: pill ≥48dp height; citation chips ≥36dp wide
- Color contrast: ≥4.5:1
- Keyboard: Tab to citations → Enter to peek → Esc to close
- Reduced motion: replace all animations with crossfades

## 10. Responsive

- Phone: card spans messages column
- Tablet: card max-width 720px, centered
- Web: same; pill anchors to top of unread separator

## 11. Theming

- Light + Dark + AMOLED variants
- Honor server accent for the ✦ glyph
- Sentiment chip color: positive=green, focused=blue, mixed=gray, tense=amber
