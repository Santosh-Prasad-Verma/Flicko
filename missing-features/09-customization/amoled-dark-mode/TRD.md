# AMOLED Dark Mode — Technical Requirements

## 1. Architecture Overview

```
+-----------------------------+
|  Settings UI                |
|  (Appearance > AMOLED)      |
+--------------+--------------+
               |
               v
+--------------+--------------+
|  amoled_provider.dart       |
|  state: enabled, mode       |
+------+----------+-----------+
       |          |          \
       v          v           v
+------+---+ +----+----+  +---+----------+
| Hive (   | | system  |  | sunset calc  |
| persist) | | dark    |  | (solar dart) |
+----------+ | listener|  +--------------+
             +---------+
                  |
                  v
         theme_engine.applyAmoled(spec)

backend mirror:
  PATCH /api/v1/users/me/settings/amoled  -> user_settings.settings.amoled
```

The renderer accepts `(ThemeSpec, AmoledOverlay) -> ThemeData` so AMOLED is composed on top of any active theme.

## 2. Components

### Backend (Go)
- **Service:** `internal/services/themes/service.go::SetAmoledPref(ctx, uid, pref)` — JSON merge into `user_settings.settings.amoled`.
- **Handler:** `internal/handlers/themes_handler.go::handlePatchAmoled` (`PATCH /api/v1/users/me/settings/amoled`).

### Mobile (Flutter)
- **Provider:** `mobile/lib/features/themes/application/amoled_provider.dart`
  - Reads/writes Hive box `amoled_settings`.
  - Mirrors changes to backend via `themesRepository.patchAmoled()`.
  - Listens to `MediaQuery.platformBrightnessOf(context)` and `Battery.onBatterySaverChanged`.
- **Renderer hook:** `mobile/lib/core/theme/theme_engine.dart::applyAmoledOverlay(ThemeData base) -> ThemeData`
  - Replaces `surface`, `surfaceContainerLow|Medium|High`, `background` with `#000000` and step values up to `#0A0A0A`.
  - Caps accent saturation via HSL adjustment.
- **UI:** `mobile/lib/features/settings/presentation/widgets/amoled_settings_section.dart`.

### Infra
- DB: `user_settings` table (see SCHEMA.md).
- Cache: Redis `user_settings:<uid>:amoled` TTL 30m.

## 3. API Contracts

### REST
```
PATCH /api/v1/users/me/settings/amoled
GET   /api/v1/users/me/settings/amoled
```

### Payloads
```jsonc
// PATCH body
{
  "enabled": true,
  "mode": "sunset"   // always | systemDark | sunset
}

// Response
{
  "enabled": true,
  "mode": "sunset",
  "updated_at": "2026-05-29T18:00:00Z"
}
```

### Realtime
- Optional Centrifugo `themes:user:<uid>` event `amoled.changed` so other devices update without refresh.

## 4. Permissions & Auth

- Self-only. `auth.uid()` must equal path `me`.
- Location permission required only when `mode=sunset`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Toggle latency | <120ms |
| Persistence write | <80ms |
| Battery savings | ≥20% on OLED idle |
| Storage | <100B per user |

## 6. Dependencies

- Existing: `full-theme-engine`.
- New libraries:
  - Flutter: `battery_plus: ^6.0.1`, `solar: ^0.0.6` (sunrise/sunset offline).

## 7. Observability

- Metrics: `flicko_amoled_enabled_total`, `flicko_amoled_mode_count{mode=...}`, `flicko_amoled_battery_suggest_accept_total`.
- Logs: pref change events.
- Trace: `themes.amoled.set`.
- Dashboard: rollup in `themes` board.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Sunset library returns invalid time | mode never activates | fallback to systemDark |
| Battery saver event missed | suggestion never fires | accept; not critical |
| Hardcoded gray sneaks past lint | visual regression | block in CI + golden test diff |
| Backend write fails | local pref still works | retry queue; eventual sync |
