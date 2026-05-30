# Full Keyboard Navigation — UI/UX Design

## 1. Design Principles

- **Tab-first.** Tab/Shift+Tab traverse in visual reading order (top-to-bottom, left-to-right, RTL flips).
- **Always-visible focus.** Focus ring is never hidden; it adapts colour to theme.
- **Discoverable.** Shortcut hints appear in menus; help overlay is one keystroke away.
- **Quiet for typers.** Single-letter shortcuts (R, E, T) only fire when focus is *not* in a text input.

## 2. Information Architecture

Where this feature lives:
- Entry points: any keystroke; `?` opens help overlay; Settings → Accessibility → Keyboard.
- Parent navigation: Settings tab.
- Deep links: `flicko://settings/accessibility/keyboard`.

## 3. Screen Inventory

| # | Screen / Surface | Purpose | States |
|---|------------------|---------|--------|
| 1 | Help overlay | List all shortcuts | content |
| 2 | Settings → Keyboard | Toggle focus ring, hints | content |
| 3 | Skip-to-content link | First focusable on every page | hidden until focused |
| 4 | Focus ring (everywhere) | Visual indicator | unfocused, focused, pressed |

## 4. Wireframes (ASCII)

### Surface 1 — Help overlay (`?` press)

```
┌─────────────────────────────────────────────────┐
│ Keyboard shortcuts                          ╳   │
├─────────────────────────────────────────────────┤
│ Search shortcuts ▶ [_____________________]      │
│                                                 │
│ Navigation                                      │
│   Cmd+K          Open quick switcher            │
│   Cmd+1..9       Jump to channel by index       │
│   Tab            Next focusable element         │
│   Shift+Tab      Previous focusable element     │
│                                                 │
│ Messaging                                       │
│   Cmd+Enter      Send message                   │
│   Shift+Enter    New line                       │
│   R              Reply to focused message       │
│   E              Add reaction                   │
│                                                 │
│ Voice & video                                   │
│   Cmd+Shift+M    Toggle mute                    │
│   Cmd+Shift+D    Toggle deafen                  │
│                                                 │
│ Press Esc to close.                             │
└─────────────────────────────────────────────────┘
```

### Surface 2 — Keyboard settings page

```
┌─────────────────────────────────────────────────┐
│ ← Keyboard                                      │
├─────────────────────────────────────────────────┤
│ ⦿ Always show focus indicator     [▣ ON ]       │
│ ⦿ Show shortcut hints in menus    [▣ ON ]       │
│ ⦿ Open help overlay with `?`      [▣ ON ]       │
│                                                 │
│ View shortcut list ──────────────────────▶      │
└─────────────────────────────────────────────────┘
```

### Surface 3 — Skip-to-content (focused)

```
┌─────────────────────────────────────────────────┐
│ [ ▶ Skip to main content ]                      │  <- visible only on focus
├─────────────────────────────────────────────────┤
│ Banner / Sidebar / Main content                 │
└─────────────────────────────────────────────────┘
```

## 5. Component Specs

### `<FocusRing>`
- Props: `child`, `radius`, `padding`.
- Uses `Focus` builder internally; reads `FocusRingTheme.of(context)`.
- Variants: idle (no ring), focused (2-3px ring), pressed (filled inset).

### `<SkipToContent>`
- Props: `targetFocusNode`.
- Hidden via `Visibility.maintain` until focused.
- On Enter → requests focus on `targetFocusNode`.
- Announces "Jumped to main content" via SemanticsService.

### `<ShortcutHelpOverlay>`
- Modal scrim 60% opacity (or solid in HC mode).
- Search field (case-insensitive substring).
- Sectioned by category: Navigation / Messaging / Voice / Server / Misc.

### `<ShortcutChip>`
- Tiny rounded chip ("Cmd+K") used inline in menus and tooltips.
- Auto-localises to OS modifier (`Cmd` vs `Ctrl`).

## 6. Empty / Error / Loading

- Help overlay search empty state: "No shortcuts match. Try another word."
- Settings page never empty.
- No errors expected (purely client).

## 7. Copy

| Surface | Copy |
|---------|------|
| Help title | "Keyboard shortcuts" |
| Help search | "Search shortcuts" |
| Settings title | "Keyboard" |
| Always show focus toggle | "Always show focus indicator" |
| Hints toggle | "Show shortcut hints in menus" |
| Help via ? | "Open help overlay with `?`" |
| Skip link | "Skip to main content" |
| Empty search | "No shortcuts match. Try another word." |
| Esc hint | "Press Esc to close." |

Voice: terse, imperative. No exclamation marks.

## 8. Motion

- Help overlay fade+slide-up 200 ms ease-out (instant under reduced motion).
- Focus ring transitions 80 ms (instant under reduced motion).

## 9. Accessibility

- The settings page itself is fully keyboard accessible (it would be embarrassing otherwise).
- Help overlay traps focus; Esc returns focus to the originator.
- Focus order matches reading order for all 25 retrofitted widgets.
- Tested with NVDA + Firefox; VoiceOver + Safari; Orca + Chromium.

## 10. Responsive

- Phone: help overlay fills screen; no `?` shortcut shown (unless external kbd attached).
- Tablet: help overlay fills 80% of screen, centred.
- Web: full overlay; sticky search.
- External-keyboard detection: `RawKeyboardListener` plus pointer-kind observer turns shortcut hints on automatically.

## 11. Theming

- Focus ring colour:
  - Light: `colorScheme.primary`
  - Dark: `colorScheme.primary` desaturated 10%
  - HC light: `#0033CC` 3px width
  - HC dark: `#FFFFFF` 3px width

## 12. Visual: focus ring spec

```
Default:  ╭─[ ]─╮  2px solid colorScheme.primary, 6px radius
HC mode:  ╔═[ ]═╗  3px solid focusOutlineHC, 6px radius
Pressed:  ╭─[#]─╮  2px solid + filled inner
```
