# Dyslexia Font — Technical Requirements

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Mobile (Flutter)                         │
│                                                                   │
│  ┌──────────────────┐       ┌──────────────────┐                │
│  │ Accessibility    │──────>│ Reader font     │                 │
│  │ preferences      │       │ provider         │                 │
│  └──────────────────┘       └──────────────────┘                │
│           │                          │                           │
│           ▼                          ▼                           │
│  ┌──────────────────────┐   ┌─────────────────────┐              │
│  │ Bundled fonts        │   │ TextTheme builder   │              │
│  │ (OpenDyslexic,       │   │ (line-height, spc) │              │
│  │  Atkinson Hyperleg.) │   └─────────────────────┘              │
│  └──────────────────────┘                                       │
│                                  │                                │
│                                  ▼                                │
│                       MaterialApp.theme.textTheme                 │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Components

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/dyslexia_font/`
  - `application/reader_font_provider.dart` — Riverpod state holding `ReaderFontPrefs { family, lineHeight, letterSpacing }`.
  - `application/text_theme_builder.dart` — pure function to build a `TextTheme` from prefs.
  - `data/preferences_datasource.dart` — read/write `accessibility_json`.
  - `presentation/screens/reader_font_settings_screen.dart`
  - `presentation/widgets/reader_font_preview.dart`
- **Asset bundle:**
  - `mobile/assets/fonts/OpenDyslexic-Regular.otf`
  - `mobile/assets/fonts/OpenDyslexic-Bold.otf`
  - `mobile/assets/fonts/AtkinsonHyperlegible-Regular.ttf`
  - `mobile/assets/fonts/AtkinsonHyperlegible-Bold.ttf`
  - `mobile/assets/fonts/LICENSE-OpenDyslexic.txt`
  - `mobile/assets/fonts/LICENSE-AtkinsonHyperlegible.txt`
- **pubspec edits:**
  - Declare both font families with regular and bold weights.
- **Cross-cutting edits:**
  - `mobile/lib/core/theme/app_theme.dart` — `textTheme` becomes a function of `ReaderFontPrefs`.
  - `mobile/lib/features/server_channels/.../code_block_widget.dart` — explicitly forces `fontFamily: 'JetBrainsMono'` to ignore reader font.
  - `mobile/lib/features/auth/.../auth_logo.dart` — keeps Flicko brand font (excluded).

### Backend (Go) — none beyond preferences
- Reuse existing `user_preferences_service`.
- `accessibility_json` keys: `reader_font_family`, `reader_line_height`, `reader_letter_spacing`.

### Infra
- DB: extends existing JSONB.
- AI: none.

## 3. API Contracts

### REST
```
GET    /api/v1/users/me/preferences         (existing)
PATCH  /api/v1/users/me/preferences         (existing)
```

### Payloads
```jsonc
{
  "accessibility": {
    "reader_font_family": "open_dyslexic",   // "system" | "open_dyslexic" | "atkinson"
    "reader_line_height": 1.6,
    "reader_letter_spacing": 0.04
  }
}
```

## 4. Permissions & Auth

- Per-user preference. No new scopes.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| APK size delta | <650 KB (after compression) |
| Theme switch latency | <80 ms |
| First-paint regression after font switch | <120 ms |
| Letter spacing range | 0 – 0.08em |
| Line height range | 1.2 – 2.0 |
| Bundle integrity | font hashes verified at build |

## 6. Dependencies

- Existing: `user_preferences_service`, `theme_provider`.
- New Flutter packages: none.
- Bundled fonts (no licence fee):
  - OpenDyslexic v3 — OFL 1.1
  - Atkinson Hyperlegible — OFL 1.1

## 7. Observability

- Metrics:
  - `flicko_accessibility_reader_font_users_gauge`
  - `flicko_accessibility_reader_font_change_total{family}`
- Logs: pref-write logs only.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Bundled font fails to load | UI falls back to default | Flutter logs error; provider auto-reverts to system |
| Some glyphs missing (CJK, emoji) | Garbled text | `fontFamilyFallback: ['NotoSans', 'NotoColorEmoji']` |
| Preference loss across reinstall | User has to re-enable | Sync preferences from server on login |
| Slider drift outside safe range | Unreadable text | Clamp on read AND write |

## 9. Font Fallback Chain

```
primary:  OpenDyslexic | AtkinsonHyperlegible | system_default
fallback: NotoSans, NotoSansArabic, NotoSansCJK, NotoColorEmoji
```

## 10. License Compliance

- OFL licence shipped under `mobile/assets/fonts/LICENSE-*.txt`.
- Settings page links to a "Font credits" dialog citing both projects.
- Do not rename the font family in the bundled OTF/TTF (OFL requirement).

## 11. Migration Path

- v0 → v1: ship behind flag, default OFF. Onboarding offers a one-tap "Try reader font" suggestion if `accessibility_json.dyslexia_self_id` is set.
- v1 → v2: add Comic Sans / Lexend / Nunito (community-requested) under separate flag.
