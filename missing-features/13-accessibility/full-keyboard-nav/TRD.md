# Full Keyboard Navigation — Technical Requirements

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                     Flutter App Root                          │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Shortcuts(shortcuts: GlobalShortcuts.map)                │ │
│  │   └── Actions(actions: GlobalActions.map)                │ │
│  │         └── FocusTraversalGroup(policy: AppPolicy)       │ │
│  │              └── MaterialApp                             │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌────────────────────┐    ┌─────────────────────────┐        │
│  │ ShortcutCatalog    │    │ FocusRingThemeExtension │        │
│  │ (single source of  │    │ (color, width, radius)  │        │
│  │ truth, l10n keys)  │    └─────────────────────────┘        │
│  └────────────────────┘                                       │
│                                                                │
│  Per-screen:                                                   │
│  ┌───────────────────────────────────────────────────────┐    │
│  │ FocusTraversalGroup → SkipToContent                   │    │
│  │   ├── Header (banner)                                  │    │
│  │   ├── Sidebar (navigation)                             │    │
│  │   └── Content (main)                                   │    │
│  └───────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

## 2. Components

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/keyboard/`
  - `application/shortcut_provider.dart` — Riverpod state for active shortcuts (allows future user remapping).
  - `application/keyboard_pref_provider.dart` — toggle for "show focus indicators always" and "show shortcut hints".
  - `domain/shortcut_catalog.dart` — canonical list of `ShortcutEntry { intent, defaultKeySet, category, l10nKey }`.
  - `presentation/widgets/focus_ring.dart` — wraps any child with a theme-aware focus ring.
  - `presentation/widgets/skip_to_content.dart` — first-focus widget that announces "Skip to main content".
  - `presentation/widgets/shortcut_help_overlay.dart` — full-screen list of all shortcuts.
  - `presentation/screens/keyboard_settings_screen.dart` — preferences page.
  - `presentation/intents/` — all `Intent` subclasses (`SendMessageIntent`, `OpenQuickSwitcherIntent`, `JumpToChannelIntent`, etc.).
- **Theme:**
  - `mobile/lib/core/theme/focus_ring_theme.dart` — `ThemeExtension<FocusRingTheme>` with light/dark/HC variants.
- **Cross-cutting edits:**
  - `mobile/lib/main.dart` or root scaffold — wrap with `Shortcuts` + `Actions` + `FocusTraversalGroup`.
  - 25 hot widgets list (mirrors `screen-reader-full` TRD): wrap interactive elements in `Focus(autofocus, focusNode, child: …)` and apply `FocusRing`.

### Backend (Go)
- No new endpoints. Shortcut preferences (when remap ships post-v1) stored in `user_preferences.accessibility_json.keyboard_shortcuts` JSONB.

### Infra
- Static catalog, no AI, no realtime.

## 3. API Contracts

### REST
```
GET    /api/v1/users/me/preferences            (existing)
PATCH  /api/v1/users/me/preferences            (existing) — keyboard prefs
```

### Payloads
```jsonc
{
  "accessibility": {
    "always_show_focus_ring": true,
    "show_shortcut_hints_in_menus": true,
    "shortcut_overrides": {
      "send_message": "Ctrl+Enter"
    }
  }
}
```

## 4. Permissions & Auth

Per-user prefs only.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Keystroke → action latency | <16 ms median (one frame) |
| Focus ring render extra cost | <0.5 ms per focused widget |
| Shortcut catalog size | ≤80 entries |
| Help overlay open time | <100 ms |

## 6. Dependencies

- Existing: `theme_provider`, `quick_switcher` (already shipped).
- New Flutter packages: none (uses Flutter built-in `Shortcuts`/`Actions`/`Focus`).

## 7. Observability

- Metrics:
  - `flicko_accessibility_shortcut_invoke_total{intent}`
  - `flicko_accessibility_focus_ring_visible_gauge`
  - `flicko_accessibility_help_overlay_open_total`
- Logs: none (purely client).

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Focus trap in custom modal | WCAG fail | Mandatory `FocusTrap` wrapper; lint rule |
| Shortcut conflicts with browser native | Unusable | Allowlist of "browser-reserved" combos; never bind them |
| Shortcut fires while typing in a textfield | Bad UX | `Shortcuts` resolver checks `currentFocus.hasPrimaryFocus && context.isInTextField` |
| RTL layout breaks arrow nav | Wrong direction | Test in `Locale('ar')`; use logical keys |
| External keyboard on iPad reports raw scancodes | Mismapping | Map via `LogicalKeyboardKey` not `PhysicalKeyboardKey` |

## 9. Default Shortcut Catalog (excerpt)

| Intent | Mac | Win/Linux | Web |
|--------|-----|-----------|-----|
| Send message | Cmd+Enter | Ctrl+Enter | Enter |
| New line | Shift+Enter | Shift+Enter | Shift+Enter |
| Open quick switcher | Cmd+K | Ctrl+K | Ctrl+K |
| Toggle mute (voice) | Cmd+Shift+M | Ctrl+Shift+M | Ctrl+Shift+M |
| Toggle deafen | Cmd+Shift+D | Ctrl+Shift+D | Ctrl+Shift+D |
| Jump to channel 1..9 | Cmd+1..9 | Ctrl+1..9 | Ctrl+1..9 |
| Open help overlay | Shift+? | Shift+? | Shift+? |
| Skip to content | Tab on first focus | Tab on first focus | Tab on first focus |
| Mark all read | Cmd+Shift+E | Ctrl+Shift+E | Ctrl+Shift+E |
| Search current channel | Cmd+F | Ctrl+F | Ctrl+F |
| Reply to focused message | R | R | R |
| React to focused message | E | E | E |
| Open thread | T | T | T |

(Full catalog of 40+ in `shortcut_catalog.dart`.)

## 10. Migration Path

- v0 → v1: ship default bindings only.
- v1 → v2: per-user remap UI; conflict detector.
