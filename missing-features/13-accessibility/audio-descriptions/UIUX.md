# Audio Descriptions — UI/UX Design

## 1. Design Principles

- **Manual wins.** Author-supplied alt-text is canonical; AI is a fallback labeled as such.
- **No friction for sighted users.** All the auto-generation work happens in the background.
- **One tap to listen.** Long-press on image → "Describe" gives both text and audio.
- **Honest about source.** A small "AI" badge appears on AI-generated descriptions.
- **Reduced motion respected** for all UI transitions.

## 2. Information Architecture

Where this feature lives:
- Entry points: long-press on any image attachment; image viewer toolbar; settings → accessibility.
- Parent navigation: attached to existing attachment widget.
- Deep links: `flicko://attachments/:id/describe`.

## 3. Screen Inventory

| # | Screen / Surface | Purpose | States |
|---|------------------|---------|--------|
| 1 | Image attachment in chat | shows alt-text on focus | content, generating, error |
| 2 | Long-press menu | "Describe" / "Edit description" | content |
| 3 | Description sheet | text + audio + report controls | content, audio playing |
| 4 | Upload sheet alt-text field | author-supplied text | empty, suggested, edited |
| 5 | Settings → Accessibility → Auto-describe | toggle + cache | content |

## 4. Wireframes (ASCII)

### Surface 1 — Image attachment with description ready

```
┌─────────────────────────────────┐
│ Asha · 09:14                    │
│ ┌────────────────────────────┐  │
│ │  [image preview]            │  │
│ │  ░░░░░░░░░░░░░░░░░░░░░░░░  │  │
│ │  ░░░░░░░░░░░░░░░░░░░░░░░░  │  │
│ └────────────────────────────┘  │
│ A black cat sitting on a window │
│ sill in afternoon light. (AI)   │
│  [▶ Listen]    [✎ Edit]         │
└─────────────────────────────────┘
```

### Surface 2 — Description sheet (bottom sheet)

```
┌─────────────────────────────────┐
│ Description                  ╳  │
├─────────────────────────────────┤
│ A black cat sitting on a window │
│ sill in afternoon light.        │
│                                 │
│ Source: AI · Model llama-3.2    │
│ Generated 09:14:30              │
│                                 │
│ [▶ Play]   [⏸ Pause]   [↻ Replay]│
│                                 │
│ Edit description ─────────────> │
│ Report problem ───────────────> │
└─────────────────────────────────┘
```

### Surface 3 — Upload alt-text editor

```
┌─────────────────────────────────┐
│ ← Add image                     │
├─────────────────────────────────┤
│ [thumbnail]                     │
│                                 │
│ Description (alt-text)          │
│ ┌────────────────────────────┐  │
│ │ Suggested by AI:            │  │
│ │ "A black cat asleep on…"    │  │
│ │ [Use] [Edit] [Skip]         │  │
│ └────────────────────────────┘  │
│                                 │
│            [ Send ]             │
└─────────────────────────────────┘
```

### Surface 4 — Settings toggle

```
┌─────────────────────────────────┐
│ ← Audio descriptions            │
├─────────────────────────────────┤
│ ⦿ Auto-play on focus  [▣ ON]    │
│   When you focus an image with  │
│   a screen reader, hear the     │
│   description automatically.    │
│                                 │
│ ⦿ Voice                         │
│   System default ▾              │
│                                 │
│ ⦿ Speed   ─────●───── 1.0x      │
└─────────────────────────────────┘
```

## 5. Component Specs

### `<DescribeButton>`
- Props: `attachmentId`, `description`, `onPlay`.
- States: idle, generating (spinner), error (retry icon).
- Tap target ≥48dp.
- Semantic label: "Describe image. Plays an audio description."

### `<AltTextEditor>`
- Props: `initialSuggestion`, `onSubmit`, `onSkip`.
- Variants: empty / has suggestion / edited.
- Character limit 280.

### `<DescriptionSheet>`
- Modal bottom sheet, max-height 60% of viewport.
- Includes audio controls, source attribution, edit/report actions.
- Closes on swipe-down with `Semantics.dismissable`.

### `<AltTextBadge>`
- Tiny pill with "AI" or "Author" tag.
- Used inline next to description text.

## 6. Empty / Error / Loading

- **Empty (no description yet):** show "Generating description…" with shimmer.
- **Generating timeout (>10s):** show "Description unavailable; tap to retry".
- **Error:** inline error banner with "Retry" — does not block image viewing.
- **NSFW image:** description replaced with "Not safe for work image. Tap to view."
- **Loading audio:** play button shows spinner until TTS speaks.

## 7. Copy

| Surface | Copy |
|---------|------|
| Long-press menu | "Describe image" |
| Listen button | "Listen" |
| Edit | "Edit description" |
| Report | "Report problem" |
| AI badge | "AI" |
| Author badge | "Author" |
| Generating | "Generating description…" |
| NSFW fallback | "Not safe for work image. Tap to view." |
| Generic failure | "Couldn't describe this image. Tap to retry." |
| Auto-play toggle | "Auto-play on focus" |
| Auto-play hint | "When you focus an image with a screen reader, hear the description automatically." |

Voice: factual, brief, never apologetic about being AI. Always disclose source.

## 8. Motion

- Description sheet slides up 250 ms ease-out.
- AI badge fades in 150 ms when description arrives.
- Reduced motion: instant.

## 9. Accessibility

- The feature itself is the accessibility primitive — but the UI must also pass:
  - Listen button has clear label and announces playback start/end.
  - Audio playback respects system mute (silent → no playback, but visible text).
  - When auto-play is on, only one description plays at a time (queue + interrupt).
  - Audio player obeys reduced-motion (no waveform animation under reduced motion).

## 10. Responsive

- Phone: bottom sheet covers 60% height.
- Tablet: side panel docked right when in image viewer.
- Web: keyboard "D" shortcut for describe action.

## 11. Theming

- Description text honors HC mode (uses high-contrast tokens when active).
- AI badge uses `colorScheme.tertiary`.

## 12. Voice & Tone for Generated Descriptions

Examples we want to ship:
- Good: "A black cat sitting on a windowsill in afternoon light."
- Good: "Two people laughing while holding mugs over a wooden table."
- Bad (vague): "An image of something."
- Bad (speculative): "Two best friends celebrating a recent promotion."
- Bad (preamble): "This image shows…"

Prompt enforces:
- ≤140 characters
- Concrete subject, location, lighting if visible
- Quote legible text in double-quotes
- No emotional speculation
