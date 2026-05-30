# Color Blind Mode — Technical Requirements

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                       Flutter App Root                       │
│                                                              │
│  ┌──────────────────┐    ┌──────────────────────────────┐   │
│  │ ColorBlindMode   │───>│ ColorFiltered(               │   │
│  │ Provider         │    │   colorFilter: matrix(preset)│   │
│  └──────────────────┘    │ )                            │   │
│           │              │   wraps MaterialApp.router    │   │
│           ▼              └──────────────────────────────┘   │
│  ┌──────────────────┐                                        │
│  │ Token overrides  │                                        │
│  │ (status, role,   │                                        │
│  │  mention, voice) │                                        │
│  └──────────────────┘                                        │
└──────────────────────────────────────────────────────────────┘
```

## 2. Components

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/color_blind/`
  - `application/color_blind_provider.dart` — `CVDPreset { off, protan, deutan, tritan }`.
  - `application/cvd_matrix.dart` — daltonization matrices for each preset.
  - `application/cvd_token_override.dart` — derive status/role/mention safe colours.
  - `data/preferences_datasource.dart`
  - `presentation/screens/color_blind_settings_screen.dart`
  - `presentation/widgets/cvd_preview_card.dart`
  - `presentation/widgets/preset_picker.dart`
  - `presentation/widgets/admin_role_color_checker.dart`
- **Cross-cutting edits:**
  - `mobile/lib/main.dart` — wrap router in `ColorFiltered` driven by provider.
  - `mobile/lib/core/theme/app_theme.dart` — token override hook.
  - `mobile/lib/features/server/.../status_indicator.dart` — colour + shape.
  - `mobile/lib/features/server_channels/.../mention_chip.dart` — palette swap + shape.
  - `mobile/lib/features/voice/.../speaker_ring.dart` — palette swap.
  - `mobile/lib/features/server_settings/.../role_color_picker.dart` — show CVD warnings.

### Backend (Go)
- No new endpoints or schema beyond preferences.

### Infra
- DB: extends existing `accessibility_json`.
- AI/Realtime/Storage: none.

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
    "color_blind_preset": "deutan",         // off | auto | protan | deutan | tritan
    "cvd_shape_supplement": true,
    "cvd_apply_filter": true                // false → palette overrides only
  }
}
```

## 4. Permissions & Auth

Per-user prefs only.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Filter render cost | <2 ms p99 per frame |
| Memory overhead | <500 KB |
| Switch latency | <60 ms |
| Token override cost | <0.5 ms per render pass |

## 6. Dependencies

- Existing: `theme_provider`, `high_contrast_mode` (combinable).
- New Flutter packages: none (uses built-in `ColorFilter.matrix`).

## 7. Observability

- Metrics:
  - `flicko_accessibility_cvd_users_gauge`
  - `flicko_accessibility_cvd_preset_total{preset}`
  - `flicko_accessibility_cvd_filter_applied_gauge`
- Logs: pref-write logs only.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Filter affects user-uploaded images unintentionally | Visual confusion | Documented as expected; "off" preset for moments user wants original |
| Token overrides clash with server accents | Brand mismatch | Server accent kept; CVD palette only on Flicko-controlled tokens |
| Filter doubled with system Color Correction | Over-corrected | Detect system pref; recommend "Auto" so we don't double up |
| Performance hit on web | Smooth scroll regress | Apply filter at compositor level; benchmark Chrome / Safari |

## 9. Daltonization Matrices

Standard daltonization (Brettel/Vienot model) with adjustable severity. Default severity 1.0.

```dart
// Deuteranopia (most common)
final ColorFilter deutanFilter = ColorFilter.matrix(<double>[
  0.625, 0.375, 0.0,   0, 0,
  0.7,   0.3,   0.0,   0, 0,
  0.0,   0.3,   0.7,   0, 0,
  0,     0,     0,     1, 0,
]);

// Protanopia
final ColorFilter protanFilter = ColorFilter.matrix(<double>[
  0.567, 0.433, 0.0,   0, 0,
  0.558, 0.442, 0.0,   0, 0,
  0.0,   0.242, 0.758, 0, 0,
  0,     0,     0,     1, 0,
]);

// Tritanopia
final ColorFilter tritanFilter = ColorFilter.matrix(<double>[
  0.95, 0.05,  0.0,   0, 0,
  0.0,  0.433, 0.567, 0, 0,
  0.0,  0.475, 0.525, 0, 0,
  0,    0,     0,     1, 0,
]);
```

## 10. Token Replacement Map

Each preset gets a small dictionary of overrides:

```
status.online    deutan  #00BFA5  (teal — distinguishable from red)
status.online    protan  #2EAC57  (greener teal)
status.online    tritan  #00BFA5  (teal works)
status.dnd       any     #E07B00  (amber, replaces red)
mention.badge    any     #1976D2  (blue, replaces red)
voice.speaking   any     #00BFA5  (teal ring with stripe)
```

## 11. Shape Supplement

When `cvd_shape_supplement: true`, status indicators include a shape:
- ●  online
- ▲  away
- ■  do-not-disturb
- ◆  streaming
- ○  offline

Drawn in addition to colour, never replacing it.

## 12. Migration Path

- v0 → v1: ship presets + filter + token overrides.
- v1 → v2: severity slider; per-channel filter exemptions for image-heavy channels.
