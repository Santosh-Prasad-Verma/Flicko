# Screen Reader Full Support — UI/UX Design

## 1. Design Principles

- Every interactive widget must declare a `semanticLabel`, `value`, and `hint` where applicable.
- Decorative imagery is wrapped in `ExcludeSemantics`.
- Custom controls implement `SemanticsConfiguration` rather than reusing default Material semantics blindly.
- Use `MergeSemantics` to coalesce visually-grouped affordances (e.g. message header = author name + timestamp + role icons).
- Honor `MediaQuery.of(context).accessibleNavigation` to scale up tap targets to 48dp (WCAG 2.5.5 enhanced).

## 2. Information Architecture

Where this feature lives:
- Entry points: Settings → Accessibility → "Screen Reader"; first-launch onboarding A11y step; system-detected auto-toggle.
- Parent navigation: Settings tab.
- Deep links: `flicko://settings/accessibility/screen-reader`.

Landmark structure on every primary scaffold:

```
banner       → top app bar (server name, status)
navigation   → left rail (server list) + bottom tab bar
main         → channel content (messages, member list, voice tile)
complementary→ right rail (member list on tablet)
contentinfo  → footer / unread divider area
```

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Settings → Accessibility → Screen Reader | Toggle verbose/polite/assertive, live region mode | content (always) |
| 2 | Onboarding step "How would you like to use Flicko?" | Detect AT and offer verbose default | initial, AT-detected, manual |
| 3 | Diagnostic A11y probe (debug) | Hover any widget to read out its semantics | active, idle |
| 4 | Verbose helper popover (first-run) | Explains what verbose mode does | one-shot |

## 4. Wireframes (ASCII)

### Screen 1 — Accessibility settings page

```
┌────────────────────────────────────────────┐
│ ← Accessibility                            │
├────────────────────────────────────────────┤
│ Screen Reader                              │
│                                            │
│ ⦿ Verbose announcements      [ ON ▣ ]      │
│   Speak more details (channel info,        │
│   unread counts, voice state).             │
│                                            │
│ ⦿ Live region mode                         │
│   ◯ Off                                    │
│   ◉ Polite (default)                       │
│   ◯ Assertive                              │
│                                            │
│ ⦿ Landmark navigation        [ ON ▣ ]      │
│   Jump between banner / nav / main with    │
│   reader gestures.                         │
│                                            │
│ Test announcement                          │
│   [ Play sample ▶ ]                        │
└────────────────────────────────────────────┘
```

### Screen 2 — Onboarding A11y step

```
┌────────────────────────────────────────────┐
│ Welcome to Flicko                  3 / 5   │
├────────────────────────────────────────────┤
│   [hand-drawn ear illustration]            │
│                                            │
│ We noticed you use TalkBack.               │
│                                            │
│ Want extra context spoken out loud         │
│ (channel info, unread counts, voice state)?│
│                                            │
│ [ Yes, verbose ]   [ Standard ]            │
│                                            │
│ You can change this any time in Settings.  │
└────────────────────────────────────────────┘
```

### Screen 3 — Debug A11y probe overlay

```
┌────────────────────────────────────────────┐
│ ╳ A11y probe                               │
├────────────────────────────────────────────┤
│ Tap any widget to inspect semantics.       │
│                                            │
│ Currently: MessageBubble                   │
│   role:   button                           │
│   label:  "Asha, 09:14 AM, Hi everyone"    │
│   hint:   "Double-tap to open thread"      │
│   missing: ✓ none                          │
└────────────────────────────────────────────┘
```

## 5. Component Specs

### `<LandmarkScaffold>`
- Props: `role: SemanticsRole`, `label: String`, `child`.
- States: idle (renders child wrapped in semantics container).
- Token usage: inherits scaffold theme; no new tokens.

### `<A11yIconButton>`
- Props: `icon`, `tooltip` (required, also used as semanticLabel), `onPressed`, `pressedHint`.
- States: idle / pressed / disabled (each emits a different `value`).
- Tap target: 48dp minimum.

### `<AnnounceOnChange>`
- Props: `value: ValueListenable<String>`, `assertive: bool`.
- Renders: `Offstage` plus `Semantics(liveRegion: true)`; pushes via `SemanticsService.announce`.

### `<FocusRing>` (visual companion)
- Renders a 2px focus ring with high contrast outline color when widget is focused.
- Token: `colorScheme.outline` for light; `colorScheme.primary` for dark.

## 6. Empty / Error / Loading

- **Empty:** Settings page never empty (always at least three toggles).
- **Error:** preference write failure shows inline banner: "Couldn't save. We'll retry when you're back online."
- **Loading:** preference read uses skeleton placeholders for switch labels (≤300 ms).

## 7. Copy

| Surface | Copy |
|---------|------|
| Settings title | "Screen reader" |
| Verbose toggle | "Verbose announcements" |
| Verbose helper | "Hear extra details: channel info, unread counts, and voice state changes." |
| Live region heading | "How urgent should new messages sound?" |
| Off | "Off" |
| Polite | "Polite — finish my current sentence first" |
| Assertive | "Assertive — interrupt to speak" |
| Sample button | "Play sample announcement" |
| Sample text | "This is what new messages sound like in Flicko." |
| Onboarding question | "Want extra context spoken out loud?" |
| Onboarding accept | "Yes, verbose" |
| Onboarding decline | "Standard" |

Voice: warm, second-person, no jargon. Avoid the word "screen reader" in the toggles themselves; place explanation underneath.

## 8. Motion

- No motion changes vs. baseline.
- Toggle switches use the standard Flicko 200 ms cubic.
- When reduced-motion is on, switches snap (0 ms).

## 9. Accessibility (meta — yes, the screen reader settings page itself)

- Every toggle is a real `Switch` with `Semantics(toggled: bool, label: ...)`.
- Radio group uses `Semantics(role: SemanticsRole.radioGroup)`.
- Sample-play button announces "Sample played" after audio ends so users hear closure.
- Tested on TalkBack 14, VoiceOver iOS 17, NVDA 2024.4.

## 10. Responsive

- Phone: vertical stack of switches (default).
- Foldable open: 2-column with explainers on right.
- Tablet: same as foldable.
- Web: keyboard-first; tab order matches visual order.

## 11. Theming

- Light, Dark, AMOLED — all share the same focus-ring logic.
- High-contrast theme uses `colorScheme.outlineVariant` ramped to AAA.
- Server accent (when present) does NOT colour the focus ring; we keep it stable.

## 12. Voice & Tone for Announcements

| Pattern | Example |
|---------|---------|
| Channel header | "general, channel. 12 unread messages." |
| Message arrival | "New message from Asha. Hi everyone." |
| Voice state | "You joined voice. Mute off. 4 members." |
| Modal open | "New server, dialog. 3 fields." |
| Modal close | "Dialog closed. Back to channel general." |
| Toast | "Message sent." |
| Error toast | "Couldn't send. Tap to retry." |

Phrasing rules:
- Lead with the noun ("Channel general, …") so reader users hear the type first.
- Avoid emoji shortcodes; replace `:fire:` with the empty string (or Unicode if explicitly typed).
- Numbers are spelled by the OS reader; don't try to localise digits ourselves.
