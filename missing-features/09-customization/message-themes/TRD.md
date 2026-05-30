# Message Themes — Technical Requirements

## 1. Architecture Overview

```
+-----------------------+
| chat_appearance_screen|
+----------+------------+
           |
           v
+----------+------------+
| messageThemeProvider  |
| (Riverpod)            |
+----+--------+---------+
     |        |
     v        v
+----+----+ +-+-------+
| Hive    | | API     |
| local   | | persist |
+---------+ +---+-----+
                |
                v
       chat_bubble.dart
       (paints shape/tail/density)
```

## 2. Components

### Backend (Go)
- **Service:** `internal/services/message_themes/service.go` — get/set with whitelist validation.
- **Handler:** `internal/handlers/message_themes_handler.go` — `GET/PUT /api/v1/users/me/message_theme`.
- **Model:** `internal/models/message_theme.go`.

### Mobile (Flutter)
- **Provider:** `mobile/lib/features/messaging/application/message_theme_provider.dart`.
- **Painter:** `mobile/lib/features/messaging/presentation/widgets/bubble_shapes.dart` (CustomPainter for tail).
- **Bubble widget:** existing `chat_bubble.dart` refactored to consume provider.
- **Settings UI:** `mobile/lib/features/settings/presentation/chat_appearance_screen.dart`.

### Infra
- DB: `message_theme_settings`.
- Cache: Redis `msg_theme:<uid>` TTL 1h.

## 3. API Contracts

### REST
```
GET /api/v1/users/me/message_theme
PUT /api/v1/users/me/message_theme
```

### Payloads
```jsonc
// PUT body
{ "shape": "rounded", "show_tail": true, "density": "cozy" }
```

## 4. Permissions & Auth

- Self-only.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Theme apply (client) | <60ms |
| Persist write | <80ms |
| Frame regression vs current | 0 |
| Storage per user | <100B |

## 6. Dependencies

- New libraries: none. Uses existing `flutter_riverpod` and `flutter` painting APIs.

## 7. Observability

- Metrics: `flicko_message_theme_set_total{shape, density}`.
- Logs: pref change events.
- Trace: `messages.theme.set`.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| CustomPainter perf regression | scroll jank | offscreen layer + memoize path |
| Density breaks attachment grid | layout glitch | golden tests cover all kinds |
| Server stale row | UI mismatch on cold start | last-write-wins; client fetch on app launch |
| Theme combo not in whitelist | reject 400 | client gates input via enum |
