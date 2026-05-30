# Aura — Server-Aware AI Chat Assistant — UI/UX Design

## 1. Design Principles

- Match Flicko's existing dark/light theme tokens (see `mobile/lib/core/theme/`)
- Aura replies inline in the channel, not as a sidebar — feels native
- Cite sources as superscript chips, expandable on tap
- Streaming text uses cursor blink ▌ during typing; settle to static glyph at done
- Refusals are warm not cold ("I couldn't find that here — want me to search elsewhere?")
- Reuse `ChatBubble`, `MarkdownRenderer`, `LoadingDots` from `shared/presentation/widgets/`

## 2. Information Architecture

Where this feature lives:
- **Entry points:**
  1. Type `@Aura` in any text channel → autocomplete chip → space → prompt
  2. Long-press any message → "Ask Aura about this"
  3. Server Settings → AI → Aura (admin only)
- **Parent navigation:** lives inside `ChannelMessagesScreen`, so no new tab.
- **Deep links:** `flicko://server/<id>/aura/settings`, `flicko://server/<id>/aura/kb`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Inline Aura reply | Streamed answer with citations | empty, streaming, done, error, refused |
| 2 | Aura mention autocomplete | Show `@Aura` chip suggestion as user types | idle, suggesting, selected |
| 3 | Aura Settings | Toggle, persona, model, rate-limit | loading, content, saving, error |
| 4 | Knowledge Base manager | List + upload + delete docs | empty, list, uploading, indexed, failed |
| 5 | Aura Dashboard (existing — extend) | Recent invocations + cost + thumbs ratio | content |

## 4. Wireframes (ASCII)

### Screen 1 — Inline Aura reply (streaming)

```
┌──────────────────────────────────────────────────┐
│ #general                                  ⋯      │
├──────────────────────────────────────────────────┤
│ alice  3:14 PM                                   │
│ @Aura where are the server rules?                │
│                                                  │
│ ╭──────────────────────────────────────────────╮ │
│ │ Aura  ✦  3:14 PM    (server-aware)           │ │
│ │ ───────────────────────────────────────────  │ │
│ │ The rules live in #welcome, pinned at the    │ │
│ │ top. Highlights:                             │ │
│ │  • be kind                                   │ │
│ │  • no NSFW outside #18plus                   │ │
│ │  • English-only in #general▌                 │ │
│ │ ───────────────────────────────────────────  │ │
│ │ sources: [¹ rules.md] [² pinned-msg]         │ │
│ │ 👍  👎    streaming…                         │ │
│ ╰──────────────────────────────────────────────╯ │
└──────────────────────────────────────────────────┘
```

### Screen 1b — Refusal state

```
╭──────────────────────────────────────────────╮
│ Aura  ✦  3:15 PM                             │
│ ───────────────────────────────────────────  │
│ I don't have that in this server's docs.     │
│ Try asking a mod, or upload a doc that       │
│ covers it.                                   │
│                                              │
│ [ ✎ Ask differently ]  [ ⤴ Notify mods ]    │
╰──────────────────────────────────────────────╯
```

### Screen 2 — Mention autocomplete

```
┌──────────────────────────────────────────────────┐
│  ╭──────────────────────────────────────────╮    │
│  │ ✦ @Aura     Server-aware AI assistant    │    │
│  │ @alice      Online                       │    │
│  │ @bob        Idle                         │    │
│  ╰──────────────────────────────────────────╯    │
│  [ @  ]  type to search…                         │
└──────────────────────────────────────────────────┘
```

### Screen 3 — Aura Settings

```
┌──────────────────────────────────────────────────┐
│ ← Aura Settings                                  │
├──────────────────────────────────────────────────┤
│ Enable Aura in this server          [  ON  ]     │
│                                                  │
│ Persona                                          │
│ ┌────────────────────────────────────────────┐   │
│ │ Casual gaming-guild voice. Use emoji       │   │
│ │ sparingly. Never reveal mod-only chans.    │   │
│ └────────────────────────────────────────────┘   │
│                                                  │
│ Model                                            │
│  (•) Fast (Groq Llama-3.3-70B)   default        │
│  ( ) Local (Ollama Llama-3.1-8B) EU/private     │
│                                                  │
│ Daily mention cap per member                     │
│  [ 30 ]  mentions / day                          │
│                                                  │
│ Knowledge base                  →  4 docs ⓘ      │
│                                                  │
│ Audit log                       →  view 124 calls│
│                                                  │
│           [   Save   ]   [  Cancel  ]            │
└──────────────────────────────────────────────────┘
```

### Screen 4 — Knowledge Base manager

```
┌──────────────────────────────────────────────────┐
│ ← Aura Knowledge — 4 / 50                        │
├──────────────────────────────────────────────────┤
│ ↑ Drop a .md / .pdf / .txt here, max 5 MB        │
│ ─────────────────────────────────────────────    │
│ ✦ rules.md                  indexed 12 chunks  ⋯ │
│ ✦ events.md                 indexed  8 chunks  ⋯ │
│ ✦ FAQ.pdf                   indexed 31 chunks  ⋯ │
│ ⏳ onboarding.md            indexing 60%         │
│                                                  │
│ Pinned messages indexed:    14 (auto)            │
│ Last reindex: 2m ago      [ Reindex now ]        │
└──────────────────────────────────────────────────┘
```

### Screen 5 — Aura Dashboard (extends existing `aura_dashboard_screen.dart`)

```
┌──────────────────────────────────────────────────┐
│ Aura ✦ Dashboard                                 │
├──────────────────────────────────────────────────┤
│ Last 7 days                                      │
│  invocations   1,204                             │
│  👍 ratio        82%                             │
│  refusals         9%   (target ≤15%)             │
│  TTFT p50      0.9 s                             │
│                                                  │
│ Top questions                                    │
│  1. "where are the rules?"            312        │
│  2. "next event time?"                188        │
│  3. "how do I get verified?"          141        │
│                                                  │
│ Cost this month                  $0.00           │
└──────────────────────────────────────────────────┘
```

## 5. Component Specs

### `AuraReplyCard`
- Props: `messageId`, `streamProvider`, `citations`, `onThumbs(rating)`
- States: `streaming` (cursor blink), `done`, `refused`, `error`
- Token usage: `colorScheme.surfaceContainerHighest`, `textTheme.bodyMedium`, accent border `colorScheme.primary @ 0.4`

### `AuraCitationChip`
- Props: `index` (¹²³…), `title`, `score`, `onTap`
- On tap: bottom sheet with chunk preview + "Open document"

### `AuraMentionChip`
- Replaces `@Aura` text token with a styled chip in the composer
- Non-deletable as chunk; backspace removes whole chip

## 6. Empty / Error / Loading

- **Empty (no KB docs):** illustration of robot reading book, "Aura works best with docs to read. Upload your first." + button
- **Error (Groq down, Ollama also down):** inline banner "Aura is napping. Try again in a moment." + retry chip
- **Loading (waiting on first token):** three-dot bouncing animation in card position; replaced by streaming text on first token (typically <1.2s)
- **Rate limited:** "You've used your 30 mentions today. Resets at midnight UTC."

## 7. Copy

| Surface | Copy |
|---------|------|
| Mention placeholder | `@Aura ask anything about this server` |
| First-token loading | `Aura is thinking…` |
| Refusal | `I don't have that in this server's docs.` |
| Rate-limited | `Daily limit reached. Resets at midnight UTC.` |
| KB empty CTA | `Drop a doc and Aura learns it in seconds.` |
| KB indexing | `Indexing… 60%` |
| Reindex done | `All caught up.` |
| Settings save | `Saved. Aura will use the new persona on next mention.` |

Voice: friendly, concise, second-person. Aura refers to itself as "Aura" never "I am an AI". No jargon.

## 8. Motion

- Token append: no animation (looks janky); cursor blink at 1Hz
- Citation chip appear: scale 0.9→1 + fade 200ms staggered 50ms each
- Refusal card: shake 8px once on first show
- Reduced motion: replace cursor blink with steady `▌`; disable shake

## 9. Accessibility

- Live region announces "Aura started replying" then full text on `done`
- Streaming text: `Semantics(liveRegion: true, label: 'aura reply, ${tokensSoFar} characters')`
- Citation chips have `Semantics(label: 'source ${index}, ${title}, relevance ${score}')`
- Color contrast: ≥4.5:1 on streaming text; cursor uses `colorScheme.primary` ≥3:1
- Keyboard: `@Aura` autocomplete navigable with arrows; Enter accepts
- Reduced motion: replace cursor blink with steady `▌`

## 10. Responsive

- Phone: full-width card
- Tablet: card max-width 720px, centered in messages column
- Web: same as tablet, mention autocomplete uses popover not bottom sheet
- Foldable: card respects display-feature posture; spans both panels in tabletop mode

## 11. Theming

- Light + Dark + AMOLED
- Aura badge color follows server accent (custom-themes feature) with fallback to `colorScheme.primary`
- "✦" sparkle glyph rendered as SVG asset `assets/icons/aura_sparkle.svg`, recolored at runtime
