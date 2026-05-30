# Full Theme Engine — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review of token list | 3d | PM/Design |
| 1 | DB schema + migration 205 | 1d | Backend |
| 2 | Validator + service + handlers | 5d | Backend |
| 3 | `theme_engine.dart` renderer + hot-swap wiring | 4d | Mobile |
| 4 | Marketplace UI screens | 5d | Mobile |
| 5 | Server theme settings + Centrifugo wiring | 3d | Both |
| 6 | QA + a11y audit + contrast suite | 3d | QA |
| 7 | Beta with 10 hand-authored themes | 5d | All |
| 8 | GA | 1d | All |

Total: ~30d wall.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/205_full_theme_engine.up.sql` (4 tables)
- [ ] Down migration
- [ ] Model `backend/internal/models/theme.go` with `ThemeSpec` struct + canonical JSON marshaller
- [ ] Validator `backend/internal/services/themes/validator.go`:
  - JSON Schema check (embedded schema asset)
  - Contrast check using `go-colorful` for each foreground/background pair
  - Whitelist token keys; reject unknown
- [ ] Service `backend/internal/services/themes/service.go`: CRUD, apply, server default, report
- [ ] Service tests, table-driven, ≥85% cov
- [ ] Handler `backend/internal/handlers/themes_handler.go`
- [ ] Handler tests
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo channel hookup `themes:user:<uid>`, `themes:server:<sid>`
- [ ] Permission middleware: owner check for server default
- [ ] Audit log entries on publish/edit/remove/report
- [ ] Metrics counters
- [ ] OpenAPI doc update
- [ ] Auto-vet cron job in `backend/internal/jobs/themes_autovet.go`

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/themes/`
- [ ] Data: `theme_dto.dart`, `themes_repository.dart`, `themes_remote.dart`, `themes_local_hive.dart`
- [ ] Domain: `theme.dart` entity, `theme_spec.dart`, `apply_theme_usecase.dart`
- [ ] Application: `app_theme_provider.dart`, `theme_marketplace_provider.dart`, `theme_preview_provider.dart`
- [ ] Renderer `mobile/lib/core/theme/theme_engine.dart`:
  - `ThemeSpec.toThemeData(brightness)` pure function
  - `FlickoThemeExtension` for non-Material tokens
- [ ] Presentation:
  - `theme_marketplace_screen.dart`
  - `theme_detail_screen.dart`
  - `theme_preview_screen.dart` (isolated subtree)
  - `applied_theme_screen.dart`
  - `server_theme_settings_screen.dart`
  - widgets: `theme_card.dart`, `token_swatch_row.dart`, `live_preview_mock_chat.dart`
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart`
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb`
- [ ] Tests: widget + provider + golden (mock chat under 6 themes)
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks

- N/A for v1. v2 considers an embedding model to recommend themes from chat history.

## 5. Files Touched (predicted)

```
backend/
  internal/services/themes/service.go             (new)
  internal/services/themes/validator.go           (new)
  internal/services/themes/schema.json            (new asset)
  internal/handlers/themes_handler.go             (new)
  internal/models/theme.go                        (new)
  internal/repo/themes_repo.go                    (new)
  internal/jobs/themes_autovet.go                 (new)
  cmd/server/main.go                              (edit)
mobile/
  lib/core/theme/theme_engine.dart                (new)
  lib/features/themes/...                         (new tree, ~15 files)
  lib/core/router/app_router.dart                 (edit)
  lib/l10n/app_en.arb                             (edit)
supabase/
  migrations/205_full_theme_engine.up.sql         (new)
  migrations/205_full_theme_engine.down.sql       (new)
```

## 6. Test Plan

- Unit: ≥85% on validator (every contrast branch covered).
- Golden tests: 6 reference themes render mock chat to fixed images.
- Integration: Postgres + Redis via testcontainers; publish + apply + auto-flag flow.
- E2E: Maestro flow — open marketplace, apply, restart app, verify persistence.
- Load: k6 — 200 rps GET marketplace for 5m, p99 <250ms.
- Accessibility: every preset passes axe + WCAG AA on text/surface pairs.
- Security: schema fuzz with `go-fuzz`; ensure no spec field can be a string with `<script>` (defense-in-depth even though we never render HTML).

## 7. Rollout & Feature Flags

- Flag: `feature.full_theme_engine.enabled`.
- Sub-flag: `feature.theme_marketplace.enabled` (engine can ship without store first).
- Default OFF in prod.
- Beta: 10 internal servers, 10 hand-authored themes seeded.
- Canary: 1% → 10% → 50% → 100% over 7d.
- Kill switch tested in staging.

## 8. Rollback Plan

1. Disable `feature.full_theme_engine.enabled` (instant).
2. Mobile clients fall back to compiled-in default theme.
3. Stop auto-vet job.
4. Revert handler routes; leave tables (cheap to keep).
5. Down migration only if data is corrupt.

## 9. Dependencies / Blockers

- Depends on: existing Material 3 theme tokens; auth; server-membership service.
- Blocks: AMOLED dark mode (built on this engine), message themes (shares the renderer).
- External: none (pure Go + Flutter).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Contrast validator false positives | M | M | Tunable threshold + admin override |
| Theme spec v2 breaks v1 clients | L | H | Strict spec_version enum + min-version gate |
| Marketplace abuse (impersonation) | M | M | Admin removal flow + `is_official` flag |
| Hot-swap flicker | M | L | Crossfade only at root MaterialApp |
| Renderer perf regression | L | H | Golden+benchmark suite gating CI |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| Storage (covers) | Appwrite free | $0 |
| Search | Meili self-hosted | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] 10 seed themes published and vetted
- [ ] Code merged to main
- [ ] INDEX status flipped to "Built"
- [ ] Metrics dashboard live
- [ ] Beta feedback ≥4.2/5
- [ ] Zero P0/P1 bugs in 7-day window
