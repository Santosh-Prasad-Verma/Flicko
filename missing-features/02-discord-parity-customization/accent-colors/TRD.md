# Accent Colors — Technical Requirements

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│ Flutter (mobile/lib/features/accent_colors)                       │
│                                                                   │
│  AccentColorScreen ──► AccentColorNotifier ──► UserSettingsRepo   │
│        │                      │                       │           │
│        └──── live preview ────┘                       ▼           │
│                                          PATCH /users/me/settings │
│                                                       │           │
│  themeDataProvider  ◄── reads accent ────────────────┘            │
│  (wraps existing ThemeData and overrides primary/secondary)      │
└──────────────────────────────────────────────────────────────────┘
                              │  HTTPS
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ Go backend                                                        │
│                                                                   │
│  user_settings_handler.go ──► user_settings_service.go            │
│         │                              │                          │
│         └─ entitlement guard ──────────┘                          │
│            (custom hex requires Flicko Plus)                      │
│                              │                                    │
│                              ▼                                    │
│                      Postgres user_settings                       │
└──────────────────────────────────────────────────────────────────┘
```

No realtime channel needed — accent is a per-user-per-device setting; if the same user is on two devices we reconcile on next settings fetch (every app foreground). No fan-out.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/user_settings_service.go` (existing) — extend `UpdateSettings` to accept `accent_color`.
- **Handler:** `backend/internal/handlers/user_settings_handler.go` (existing) — add validation, entitlement check.
- **Model:** `backend/internal/models/user_settings.go` — add `AccentColor string` field with `db:"accent_color"` and JSON tag `omitempty`.
- **Validation helper:** `backend/internal/services/accent_color_validator.go` (new, ~60 LOC). Validates hex, contrast, palette membership.

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accent_colors/`
  - `data/accent_color_repository.dart` — uses existing `DioClient`.
  - `domain/accent_palette.dart` — the curated 16 swatches as `const` list.
  - `domain/accent_validator.dart` — mirror of backend hex/contrast checks.
  - `application/accent_color_provider.dart` — `Notifier<Color>` with persistence.
  - `presentation/accent_color_screen.dart` — main picker.
  - `presentation/widgets/swatch_grid.dart`, `swatch_tile.dart`, `live_preview.dart`, `custom_hex_sheet.dart`.

### Infra
- DB: Supabase Postgres `user_settings.accent_color TEXT NOT NULL DEFAULT '#7C5CFF'`.
- Cache: existing settings cache `user:settings:{user_id}` (Redis, TTL 5m) — no new key.
- Realtime: none.
- Storage: none.
- AI: none.
- Queue: none.

## 3. API Contracts

### REST (existing endpoint, extended)

```
GET    /api/v1/users/me/settings          read
PATCH  /api/v1/users/me/settings          update partial
```

### Payloads

```jsonc
// PATCH /api/v1/users/me/settings
{
  "accent_color": "#7C5CFF"
}

// 200 OK
{
  "user_id": "0c2a...",
  "theme": "dark",
  "accent_color": "#7C5CFF",
  "updated_at": "2026-05-29T12:00:00Z"
}

// 400 — bad hex
{ "error": "invalid_accent_color", "message": "must be 6-digit hex" }

// 402 — custom hex requires Plus
{ "error": "accent_color_requires_plus", "allowed": ["#7C5CFF","#FF6B6B", ...] }

// 422 — palette violation
{ "error": "accent_contrast_too_low", "ratio": 2.9, "minimum": 4.5 }
```

### Validation rules (backend)
1. Regex `^#[0-9A-Fa-f]{6}$`.
2. If hex is in the curated 16, accept regardless of plan.
3. If hex is not in palette and user is not Plus, reject 402.
4. If hex is not in palette and user is Plus, compute relative luminance; require ≥4.5:1 against `#0F0F14` AND `#FFFFFF`. Otherwise 422.

### WebSocket / Centrifugo
None — single-user setting, polled on foreground.

## 4. Permissions & Auth

- Required scope: `users.settings.write` (already granted to all logged-in users).
- No role checks — every authenticated user owns their accent.
- RLS on `user_settings` already enforces `user_id = auth.uid()`.
- Entitlement check: `services.PremiumService.HasFeature(userID, "accent_color_custom_hex")`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency PATCH | <80 ms |
| p99 latency PATCH | <250 ms |
| Throughput | 200 rps cluster-wide (low) |
| Availability | 99.9% (rides on user_settings SLO) |
| Storage cost | $0 — single varchar(7) on existing row |
| Compute cost | $0 — single UPDATE statement |
| Mobile cold-start cost | <2 ms to load cached accent from `SharedPreferences` |
| Theme rebuild | <1 frame (`ThemeData.copyWith` only) |

## 6. Dependencies

- Existing services: `user_settings_service.go`, `premium_handler.go`, `flicko_feature_flags`.
- New libraries: none. Reuses `chroma` math from `mobile/lib/core/theme/app_theme.dart`.
- External APIs: none.

## 7. Observability

- Metrics:
  - `flicko_accent_color_changes_total{plan="free|plus", source="palette|custom"}`
  - `flicko_accent_color_validation_failures_total{reason}`
- Logs: structured at INFO `{event: "accent_changed", user_id, color, plan}`. Errors → Sentry with `feature: accent_colors` tag.
- Traces: OTel span `user_settings.update` already exists; child span `accent.validate`.
- Dashboards: extend existing "User Settings" Grafana board with one row of accent panels.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Backend PATCH times out | Local accent stays applied; banner says "saved locally, will sync" | retry queue in `accent_color_provider.dart` |
| Backend returns 402 (downgrade Plus mid-session) | Custom hex falls back to nearest palette swatch | client computes nearest in HSL space |
| DB write succeeds but reply lost | Next foreground GET reconciles | last-write-wins on `updated_at` |
| Bad hex in DB (e.g. dirty migration) | App falls back to default `#7C5CFF` | client validates on read |
| Theme rebuild jank on low-end | No measurable jank in benchmark — `ThemeData.copyWith` is cheap | document upper-bound |

## 9. Security & Privacy

- Accent color is not PII but is a user attribute; included in GDPR export under `user_settings`.
- No XSS surface — color is rendered via `Color(0xff...)`, never as inline CSS.
- Custom hex still validated server-side; never trust client.
