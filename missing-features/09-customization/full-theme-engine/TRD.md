# Full Theme Engine — Technical Requirements

## 1. Architecture Overview

```
                +-------------------------+
                |  Theme Marketplace UI   |
                |  (mobile, Flutter)      |
                +-----------+-------------+
                            |
                            v
+------------------+   REST  +------------------------+
| theme_engine.dart| <-----> | themes_handler.go      |
| (renderer)       |         |                        |
+--------+---------+         +-----------+------------+
         |                                |
         | tokens                         v
         v                       +--------+--------+
+--------+--------+              | themes_service  |
| Material3 Theme |              | (Go)            |
| + extensions    |              +---+---------+---+
+-----------------+                  |         |
                                     v         v
                              +------+--+   +--+--------+
                              | Postgres|   | Appwrite  |
                              | themes  |   | bucket    |
                              +---------+   | covers/   |
                                            +-----------+
```

Tokens travel as canonical JSON. The Flutter renderer hydrates a `ThemeData` plus a `FlickoThemeExtension` carrying any tokens not native to Material 3 (chat bubble radius, sidebar density, etc.). Hot-swap is achieved by lifting `MaterialApp.theme` from a Riverpod `appThemeProvider`.

## 2. Components

### Backend (Go)
- **Service:** `internal/services/themes/service.go` — CRUD, validation, vetting.
- **Validator:** `internal/services/themes/validator.go` — JSON Schema check, contrast checks (WCAG AA on `surface` vs `onSurface`), token whitelist.
- **Handlers:** `internal/handlers/themes_handler.go`
- **Models:** `internal/models/theme.go`
- **Repo:** `internal/repo/themes_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/themes/`
  - `data/` — `themes_repository.dart`, `theme_dto.dart`
  - `domain/` — `theme.dart` entity, `apply_theme_usecase.dart`
  - `application/` — `theme_marketplace_provider.dart`, `app_theme_provider.dart`
  - `presentation/` — `theme_marketplace_screen.dart`, `theme_preview_screen.dart`, `widgets/theme_card.dart`
- **Renderer:** `mobile/lib/core/theme/theme_engine.dart` — pure function `ThemeSpec -> (ThemeData light, ThemeData dark, FlickoThemeExtension)`.
- **Storage:** Hive box `applied_theme` for offline persistence.

### Infra
- DB: Supabase Postgres tables `themes`, `user_theme_overrides` (see SCHEMA.md).
- Storage: Appwrite bucket `theme_covers` for preview thumbnails (max 256KB).
- Cache: Redis `theme:<id>` TTL 10m; `theme:list:popular` TTL 1m.
- Search: Meilisearch index `themes` for marketplace search.

## 3. API Contracts

### REST
```
GET    /api/v1/themes                  list (paged, sortable, searchable)
GET    /api/v1/themes/:id              read full spec
POST   /api/v1/themes                  publish (creator only)
PATCH  /api/v1/themes/:id              edit (creator only, re-vets)
DELETE /api/v1/themes/:id              soft delete
POST   /api/v1/themes/:id/apply        set as user override
DELETE /api/v1/themes/apply            clear user override
POST   /api/v1/themes/:id/report       flag for review
GET    /api/v1/servers/:sid/theme      read server default
PUT    /api/v1/servers/:sid/theme      set server default (owner)
```

### Payloads
```jsonc
// POST /themes — body
{
  "name": "Tokyo Night",
  "author_blurb": "@mira",
  "spec_version": 1,
  "spec": {
    "colors": { "primary": "#7AA2F7", "surface": "#1A1B26", "...": "..." },
    "radii": { "sm": 6, "md": 12, "lg": 20 },
    "spacing": { "xs": 4, "sm": 8, "md": 16 },
    "motion": { "fastMs": 120, "mediumMs": 240, "slowMs": 360 },
    "typeWeights": { "body": 400, "title": 600, "display": 700 }
  },
  "cover_url": "https://cdn.flicko.app/theme_covers/abc.webp"
}
```

### Realtime
- Centrifugo channel `themes:user:<uid>` — push when override changes from another device.
- Channel `themes:server:<sid>` — push when server default changes.

## 4. Permissions & Auth

- Read: any authed user.
- Publish/edit: any authed user (rate-limited to 5 publishes/day, 20 edits/day).
- Set server default: server owner or `manage_server` permission.
- Vet/takedown: `flicko_admin` role.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 list latency | <80 ms |
| p99 list latency | <250 ms |
| Apply theme client-side | <16 ms |
| Validation latency | <120 ms |
| Marketplace availability | 99.9% |
| Storage cost per theme | <5 KB JSON + 256 KB cover |
| Compute cost per validation | <$0.0001 |

## 6. Dependencies

- Existing services: auth, server membership, audit log.
- New libraries:
  - Go: `github.com/santhosh-tekuri/jsonschema/v5` (schema validation), `github.com/lucasb-eyer/go-colorful` (contrast).
  - Flutter: existing `flex_color_scheme: ^7.3.1` reused.

## 7. Observability

- Metrics: `flicko_themes_published_total`, `flicko_themes_applied_total`, `flicko_themes_validation_duration_seconds`, `flicko_themes_takedown_total`.
- Logs: structured JSON, `theme_id`, `user_id` redacted by default.
- Traces: OTel spans `themes.validate`, `themes.apply`, `themes.list`.
- Dashboard: Grafana board `themes`.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Validation panic on malformed spec | reject publish | recover + 400 |
| Spec uses unknown token key | renderer falls back to default | strict server-side rejection on publish |
| Server-default theme deleted | members fall back to user theme | cache last good spec for 24h |
| Marketplace search down | direct fetch by id still works | UI banner |
| Hot-reload causes flicker | UX regression | crossfade 120ms transition |
