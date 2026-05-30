# Auto-Translate — Inline Per-Message Translation — UI/UX Design

## 1. Design Principles

- The original message is sacred — translation appears underneath, never replaces unless user opts in
- Inline button is muted (gray), only colors up on hover/long-press
- Auto-translate (when enabled) shows "auto" badge so users know it's not the user's typed words
- Glossary protection visible: `__bracketed__` words shown unchanged with subtle dotted underline

## 2. Information Architecture

- **Entry points:**
  1. Tap the small `Aa` translate icon under any foreign-language message (auto-shown)
  2. Long-press message → "Translate" item
  3. Server settings → AI → Translation
  4. Personal settings → Languages → Default target language
- **Deep links:** `flicko://settings/translate`, `flicko://server/<id>/translate/glossary`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Inline translate toggle | Show/hide translation under msg | hidden, button, expanded |
| 2 | Translation bubble | Translated text under original | loading, content, error |
| 3 | User Settings — Languages | Pick target lang + behavior | loading, content, saving |
| 4 | Server Settings — Translation | Toggle, channel allowlist | content |
| 5 | Glossary admin | Add/remove protected terms | empty, list, adding |

## 4. Wireframes (ASCII)

### Screen 1+2 — Inline translate

```
┌───────────────────────────────────────────────┐
│ yuki  3:14 PM                                 │
│ こんにちは!元気ですか?                          │
│ ╭ Aa  ja → en ───────────────────────────╮   │
│ │ Hello! How are you?                    │   │
│ │ via libretranslate · cached            │   │
│ ╰──────────── show original   👍 👎 ✕ ───╯   │
└───────────────────────────────────────────────┘
```

### Screen 1 — Collapsed (button only)

```
┌───────────────────────────────────────────────┐
│ yuki  3:14 PM                                 │
│ こんにちは!元気ですか?                          │
│  Aa  Translate                                │
└───────────────────────────────────────────────┘
```

### Screen 3 — User Languages

```
┌───────────────────────────────────────────────┐
│ ← Languages                                   │
├───────────────────────────────────────────────┤
│ Translate other languages to                  │
│  English   ▼                                  │
│                                               │
│ When I see a message I don't understand       │
│  ( ) always translate automatically           │
│  (•) show a translate button                  │
│  ( ) never                                    │
│                                               │
│ Languages I read fluently                     │
│  [ en ] [ ja ] [+]                            │
│  (don't auto-translate these)                 │
│                                               │
│ Daily quota:  47 / 1000 used                  │
└───────────────────────────────────────────────┘
```

### Screen 4 — Server Translation Settings

```
┌───────────────────────────────────────────────┐
│ ← Translation                                 │
├───────────────────────────────────────────────┤
│ Show translate button on messages   [ON]      │
│                                               │
│ Auto-translate without tapping      [ON]      │
│   (overrides per-user "ask" mode)             │
│                                               │
│ Channels                                      │
│  ☑ #general                                   │
│  ☑ #intl                                      │
│  ☐ #dev   (English only)                      │
│                                               │
│ Glossary                       →  12 terms    │
└───────────────────────────────────────────────┘
```

### Screen 5 — Glossary admin

```
┌───────────────────────────────────────────────┐
│ ← Glossary — 12 terms                         │
├───────────────────────────────────────────────┤
│ + add term                                    │
│ ───────────────────────────────────────────   │
│ Frostmourne          [skip translate]    ⋯    │
│ Ironforge            [skip translate]    ⋯    │
│ pog                  [skip translate]    ⋯    │
└───────────────────────────────────────────────┘
```

## 5. Component Specs

### `TranslateInlineButton`
- Props: `messageId`, `srcLang`, `tgtLang`, `onTap`
- Renders below message bubble; auto-collapses if user dismisses thrice in 24h (LRU memory)

### `TranslationBubble`
- Props: `messageId`, `originalText`, `translatedText`, `provider`, `cached`, `onShowOriginal`, `onFeedback`
- Includes provider attribution as subtle gray text

### `GlossaryEditor`
- Props: list, `onAdd`, `onDelete`
- Validates max 200 terms, term length ≤64 chars, case-sensitive flag

## 6. Empty / Error / Loading

- **Loading:** shimmer line under msg ~80% width, ~600ms before result
- **Error:** "Translation unavailable. Try again?" inline; tap retries
- **Refused (same language):** button hidden; if forced, show "This is already in <lang>."
- **Provider degraded:** banner "Using fallback translator — quality may be lower."
- **Daily limit:** button disabled with tooltip "Daily translation limit reached."

## 7. Copy

| Surface | Copy |
|---------|------|
| Button | `Aa Translate` |
| Auto-translated badge | `auto · ja → en` |
| Provider | `via libretranslate` / `via deepl` |
| Cache hit | `cached` |
| Show original | `show original` |
| Same lang | `This message is already in English.` |
| Quota | `Daily limit reached. Resets at midnight UTC.` |

## 8. Motion

- Translation bubble expand: height tween 200ms ease-out
- Loading shimmer: 1.2s loop
- Reduced motion: instant snap

## 9. Accessibility

- Live region announces translation when expanded: "translated from Japanese to English: Hello! How are you?"
- Button has `Semantics(label: 'Translate this Japanese message to English')`
- Glossary editor: focus trap; Esc closes
- Screen-reader users get `auto-translate` announcement via polite region on first arrival in channel

## 10. Responsive

- Phone: bubble spans message width
- Tablet/Web: bubble max-width 720px
- Foldable: tooltip in tabletop mode shows on hover

## 11. Theming

- Translation bubble uses `colorScheme.surfaceContainerLow`
- Provider badge uses `textTheme.labelSmall` at 0.6 opacity
- Glossary terms styled `JetBrainsMono` font for code-like distinction
