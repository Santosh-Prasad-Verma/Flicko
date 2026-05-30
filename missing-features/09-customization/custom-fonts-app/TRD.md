# Custom Fonts — Technical Requirements

## 1. Architecture Overview

```
+------------------+    +----------------------+
| Settings UI      |--->| font_choice_provider |
+------------------+    +----------+-----------+
                                   |
                                   v
                        +----------+-----------+
                        | theme_engine.dart    |
                        | TextTheme builder    |
                        +----------+-----------+
                                   |
                                   v
                          MaterialApp.theme

backend mirror:
GET/PUT /api/v1/users/me/fonts -> font_choices
```

## 2. Components

### Backend (Go)
- **Service:** `internal/services/fonts/service.go` — get/set with whitelist validation.
- **Handler:** `internal/handlers/fonts_handler.go` — `GET/PUT /api/v1/users/me/fonts`.
- **Model:** `internal/models/font_choice.go`.

### Mobile (Flutter)
- **Provider:** `mobile/lib/features/themes/application/font_choice_provider.dart`.
- **Theme integration:** `mobile/lib/core/theme/theme_engine.dart::buildTextTheme(FontChoice)`.
- **Settings UI:** `mobile/lib/features/settings/presentation/font_settings_screen.dart`.
- **Platform channel:** `mobile/lib/core/platform/system_font_channel.dart` (Android only). On iOS returns `null` and UI hides toggle.

### Infra
- DB: `font_choices`.
- Cache: Redis `font_choice:<uid>` TTL 1h.
- Storage (v2): Appwrite bucket `user_fonts`.

## 3. API Contracts

### REST
```
GET /api/v1/users/me/fonts
PUT /api/v1/users/me/fonts
```

### Payloads
```jsonc
// PUT body
{
  "body_family": "OpenDyslexic",
  "header_family": "Inter",
  "mono_family": "JetBrainsMono",
  "use_system": false
}

// Response
{
  "body_family": "OpenDyslexic",
  "header_family": "Inter",
  "mono_family": "JetBrainsMono",
  "use_system": false,
  "uploaded_url": null,
  "updated_at": "2026-05-29T18:00:00Z"
}
```

## 4. Permissions & Auth

- Self-only.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Persistence write | <80ms |
| Font swap | <50ms |
| APK size delta | <3MB |
| Cold start delta | <20ms |
| Crash rate from font load | 0 |

## 6. Dependencies

- New libraries:
  - Flutter: `google_fonts: ^6.2.1` (used only for non-bundled families), already-bundled local assets for accessibility fonts.

## 7. Observability

- Metrics: `flicko_font_choice_set_total{family}`, `flicko_font_choice_use_system_total`.
- Logs: pref change events with anonymized user_id.
- Trace: `fonts.set`.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| GoogleFonts CDN miss | font fails to load | bundle critical fallback in app |
| Whitelist drops a font | client got removed family | server maps to nearest + toast |
| Font asset corrupt at build | runtime crash | CI integration test on all bundled fonts |
| iOS system font unavailable | toggle hidden | UI gates by platform |
