# Custom Fonts (Basic) — Technical Requirements

## 1. Architecture Overview

```
┌───────────────────────────────────────────────────────────────┐
│ Mobile (Flutter) — only side that touches fonts                │
│                                                                │
│  pubspec.yaml ──► assets/fonts/{Inter,OpenDyslexic,...}.ttf    │
│  (declared with `family:` keys; no runtime download)           │
│                                                                │
│  FontFamilyNotifier (Riverpod) ◄─ user_settings ◄─ API         │
│        │                                                       │
│        ▼                                                       │
│  themeDataProvider                                             │
│   ├─ ThemeData.copyWith(textTheme: textTheme.apply(            │
│   │     fontFamily: chosen,                                    │
│   │     fontFamilyFallback: [systemFallback, 'Inter']))        │
│   └─ codeBlockTextStyle = uses JetBrainsMono regardless        │
└───────────────────────────────────────────────────────────────┘
                              │ HTTPS
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ Go backend                                                    │
│                                                               │
│  user_settings_handler.go                                     │
│        │                                                      │
│        ▼                                                      │
│  user_settings_service.go ── validate(font_family ∈ allowed)  │
│        │                                                      │
│        ▼                                                      │
│  Postgres user_settings.font_family                           │
└──────────────────────────────────────────────────────────────┘
```

The backend never serves fonts; it only stores the chosen identifier. Fonts are bundled in the Flutter app build.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/user_settings_service.go` (existing) — extend `UpdateSettings` with `font_family`.
- **Handler:** `backend/internal/handlers/user_settings_handler.go` (existing) — passes through validated value.
- **Model:** `backend/internal/models/user_settings.go` — add `FontFamily string` field.
- **Validator:** `backend/internal/services/font_family_validator.go` (new, ~30 LOC):
  - `var allowedFonts = []string{"inter","roboto","opendyslexic","atkinson","jetbrains_mono","lora","comfortaa"}`
  - `IsAllowed(name string) bool`.

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/custom_fonts/`
  - `data/font_repository.dart` — call existing user-settings repo for `font_family`.
  - `domain/font_catalog.dart` — `const` list of `FontEntry { id, displayName, weight, sample, license, dyslexiaFriendly }`.
  - `application/font_family_provider.dart` — Riverpod `Notifier<String>` reading from `SharedPreferences` first, then reconciling with backend.
  - `presentation/font_picker_screen.dart`.
  - `presentation/widgets/font_card.dart`, `live_chat_preview.dart`.
- **Theme integration:** edit `mobile/lib/core/theme/theme_provider.dart` to apply `fontFamily` from `fontFamilyProvider`.
- **Asset integration:** edit `mobile/pubspec.yaml`:
  ```yaml
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter/Inter-Regular.ttf
        - asset: assets/fonts/Inter/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter/Inter-Bold.ttf
          weight: 700
    - family: OpenDyslexic
      fonts:
        - asset: assets/fonts/OpenDyslexic/OpenDyslexic-Regular.ttf
        - asset: assets/fonts/OpenDyslexic/OpenDyslexic-Bold.ttf
          weight: 700
    # ... 5 more
  ```

### Infra
- DB: Postgres `user_settings.font_family TEXT NOT NULL DEFAULT 'inter'`.
- Cache: existing `user:settings` cache; no new key.
- No realtime, no storage, no AI, no queue.

## 3. API Contracts

### REST (existing endpoint, extended)

```
GET    /api/v1/users/me/settings
PATCH  /api/v1/users/me/settings
```

### Payloads

```jsonc
// PATCH
{ "font_family": "opendyslexic" }

// 200 OK
{
  "user_id": "0c2a...",
  "theme": "dark",
  "accent_color": "#7C5CFF",
  "font_family": "opendyslexic",
  "updated_at": "2026-05-29T12:00:00Z"
}

// 422 unknown font
{ "error": "invalid_font_family", "allowed": ["inter","roboto","opendyslexic","atkinson","jetbrains_mono","lora","comfortaa"] }
```

### Validation rules
- Field is optional in PATCH.
- If present, must be in the whitelist.
- Future-proofing: backend reads whitelist from a `font_catalog` constant; clients also embed a copy. If mismatch (server adds new font before client ships), client falls back to Inter for unknown values; server is authoritative.

### WebSocket / Centrifugo
None — single-user setting, polled on app foreground.

## 4. Permissions & Auth

- Required scope: `users.settings.write` (already granted to all logged-in users).
- No role checks; every authenticated user owns their font.
- RLS on `user_settings` already enforces `user_id = auth.uid()`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency PATCH | <80 ms |
| p99 latency PATCH | <250 ms |
| Font swap time (UI rebuild) | <1 frame (`ThemeData.copyWith`) |
| App size delta | ≤4.0 MB compressed; CI gate |
| Cold start regression | <30 ms p95 (fonts loaded lazily by Flutter) |
| Storage cost | $0 (one TEXT column) |
| Compute cost | $0 (rides PATCH /settings) |
| Availability | 99.9% (rides user_settings SLO) |

## 6. Dependencies

- Existing services: `user_settings_service.go`, `flicko_feature_flags`.
- New libraries: none (Flutter has built-in font support).
- External: SIL OFL fonts (Inter, OpenDyslexic, Atkinson Hyperlegible, JetBrains Mono, Lora, Comfortaa). Roboto is Apache 2.0. All license files committed to `mobile/assets/fonts/<family>/LICENSE.txt`.

## 7. Observability

- Metrics:
  - `flicko_font_family_changes_total{family}` (Prometheus counter).
  - `flicko_font_family_validation_failures_total{reason}`.
- Logs: `{event:"font_changed", user_id, family, prev_family}`. Errors → Sentry.
- Traces: existing `user_settings.update` span; cheap.
- Dashboards: extend existing User Settings Grafana board with a "Font usage" panel (top families).

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Font asset missing in build | UI falls back to system | CI test verifies all 7 fonts load on first run |
| User on offline first launch | local default 'inter' | reconciles on first foreground after auth |
| Server returns unknown font (after rollback) | client falls back to 'inter' | safe default + Sentry breadcrumb |
| Bold-text system setting | text bolder than expected | tested across all 7 families |
| Glyph missing for non-Latin script | renders tofu | Flutter fallback chain to system font |

## 9. Asset Strategy

- All fonts subset to Latin + Latin Extended A/B + Cyrillic + Greek where the source supports it.
- Subsetting via `pyftsubset` in `mobile/scripts/subset_fonts.py`, run as a build step.
- Hinting kept (autohint).
- Variable fonts NOT used in v1 (Flutter variable-axis support is patchy on iOS); we ship Regular + Bold only.
- Per-family budget: ≤ 600 KB compressed per family across all weights.
