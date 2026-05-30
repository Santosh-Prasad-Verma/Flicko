# High Contrast Mode — Technical Requirements

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   Mobile (Flutter) — Primary                     │
│                                                                   │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │ MediaQuery       │───>│ HighContrast     │                   │
│  │ .highContrast    │    │ ThemeResolver    │                   │
│  └──────────────────┘    └──────────────────┘                   │
│           │                       │                              │
│           ▼                       ▼                              │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │ User pref store  │───>│ ThemeProvider    │                   │
│  │ (accessibility)  │    │ (Riverpod)       │                   │
│  └──────────────────┘    └──────────────────┘                   │
│                                  │                                │
│                                  ▼                                │
│                       ┌─────────────────────┐                    │
│                       │ MaterialApp.theme = │                    │
│                       │ highContrastLight / │                    │
│                       │ highContrastDark    │                    │
│                       └─────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Components

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/high_contrast/`
  - `application/high_contrast_provider.dart` — Riverpod state of the toggle (`HighContrastMode { off, auto, onLight, onDark }`).
  - `application/contrast_resolver.dart` — derives effective ThemeData given system + user pref.
- **Theme files:**
  - `mobile/lib/core/theme/high_contrast_theme.dart` — exports `highContrastLightTheme`, `highContrastDarkTheme`.
  - `mobile/lib/core/theme/contrast_tokens.dart` — token constants (AAA palette, focus ring, borderEmphasis).
  - `mobile/lib/core/theme/theme_provider.dart` — extended to dispatch to HC themes.
- **Cross-cutting edits:**
  - `mobile/lib/core/theme/app_theme.dart` — add HC variant resolution.
  - `mobile/lib/features/server/.../accent_resolver.dart` — clamp server accent to safe-set when HC active.
  - `mobile/lib/features/server_channels/.../message_bubble.dart` — replace gradient with flat fill in HC mode.
  - `mobile/lib/features/voice/.../voice_tile.dart` — increase border weight to 2px when HC active.

### Backend (Go) — none beyond preferences
- Reuse existing `user_preferences_service` for the toggle.
- No new schema; the existing `accessibility_json` JSONB column gets a `high_contrast_mode` key.

### Infra
- DB: extends existing JSONB; no new tables.
- Realtime: none.
- Cache: client only.
- Storage: none.
- AI: none.

## 3. API Contracts

### REST
```
GET    /api/v1/users/me/preferences         (existing) reads accessibility_json
PATCH  /api/v1/users/me/preferences         (existing) writes high_contrast_mode
```

### Payloads
```jsonc
{
  "accessibility": {
    "high_contrast_mode": "auto",   // "off" | "auto" | "on_light" | "on_dark"
    "neutralize_server_accents": true
  }
}
```

## 4. Permissions & Auth

- All changes are per-user; no scope changes.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Theme switch latency | <60 ms (no app reload) |
| Memory overhead | <300 KB (color tables) |
| Token contrast ratios (body text) | ≥7:1 |
| Token contrast ratios (large text/components) | ≥4.5:1 |
| CI contrast verification | runs on every theme change |

## 6. Dependencies

- Existing services: `user_preferences_service`, `theme_provider`.
- New Flutter packages: none (all native APIs).
- External APIs: none.

## 7. Observability

- Metrics:
  - `flicko_accessibility_hc_users_gauge`
  - `flicko_accessibility_hc_mode_adoption_total{mode}`
- Logs: standard preference-write logs.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Server accent override breaks community branding | UX backlash | Honour `neutralize_server_accents=false` to opt out |
| OS high-contrast pref not surfaced (older Android) | Auto mode misses | Fallback to manual toggle |
| Theme switch flicker | Jank | Use `AnimatedTheme` with 100 ms cross-fade (or 0 ms if reduced motion) |
| Token drift over time | AAA regressions | CI golden contrast test |

## 9. Token Reference (light)

```
surface              #FFFFFF
onSurface            #000000   (21:1 vs surface)
surfaceVariant       #F4F4F4
onSurfaceVariant     #1A1A1A   (15.6:1 vs surfaceVariant)
primary              #0033CC
onPrimary            #FFFFFF   (10.8:1)
primaryContainer     #DCE8FF
onPrimaryContainer   #001A66
error                #B00020
onError              #FFFFFF
focusOutlineHC       #0033CC
borderEmphasis       #1A1A1A
```

## 10. Token Reference (dark)

```
surface              #000000
onSurface            #FFFFFF   (21:1)
surfaceVariant       #1A1A1A
onSurfaceVariant     #F0F0F0   (16.4:1)
primary              #66B3FF
onPrimary            #001A33
primaryContainer     #003D80
onPrimaryContainer   #DDEBFF
error                #FF6B6B
onError              #1A0000
focusOutlineHC       #FFFFFF
borderEmphasis       #FFFFFF
```

## 11. Contrast Verification

A CI script `tools/check_contrast.dart` reads both theme files, computes WCAG contrast ratio between every (background, foreground) token pair declared in `contrast_tokens.dart`, and fails the build if any pair specified for body text is below 7:1 or any large-text/component pair below 4.5:1.

## 12. Migration Path

- v0 → v1: ship behind flag, OS-detection respects existing system pref. Manual toggle persists across reinstalls (server-side).
- v1 → v2: per-server accent denylist, custom AAA palettes per locale (right-to-left languages prefer slightly higher contrast).
