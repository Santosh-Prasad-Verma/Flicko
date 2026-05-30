# Message Themes — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 1d | PM/Design |
| 1 | DB migration 210 | 0.5d | Backend |
| 2 | Backend persistence | 1d | Backend |
| 3 | `chat_bubble.dart` refactor for shape/tail/density | 3d | Mobile |
| 4 | Settings screen with preview | 2d | Mobile |
| 5 | Provider + sync | 1d | Mobile |
| 6 | Golden test suite (attachments, reactions, replies) | 2d | Mobile |
| 7 | QA + a11y audit | 1d | QA |
| 8 | GA | 1d | All |

Total: ~12d.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/210_message_theme_settings.up.sql`.
- [ ] Down migration.
- [ ] Model `backend/internal/models/message_theme.go`.
- [ ] Service `backend/internal/services/message_themes/service.go`.
- [ ] Handler `backend/internal/handlers/message_themes_handler.go`.
- [ ] Wire routes.
- [ ] Service tests.

## 3. Mobile Tasks

- [ ] Provider `mobile/lib/features/messaging/application/message_theme_provider.dart`.
- [ ] Repository + DTO + datasource.
- [ ] Refactor `mobile/lib/features/messaging/presentation/widgets/chat_bubble.dart`:
  - extract `BubbleShape`, `BubbleTail` painters.
  - density via `MessageDensity` enum applied to padding + line-height.
- [ ] Settings screen `mobile/lib/features/settings/presentation/chat_appearance_screen.dart`.
- [ ] Live preview using mock messages in isolated subtree.
- [ ] L10n keys.
- [ ] Tests: provider state; widget golden of message thread under each combo (3*2*3 = 18 goldens).

## 4. AI / Infra Tasks

- N/A.

## 5. Files Touched (predicted)

```
backend/
  internal/services/message_themes/service.go     (new)
  internal/handlers/message_themes_handler.go     (new)
  internal/models/message_theme.go                (new)
  cmd/server/main.go                              (edit)
mobile/
  lib/features/messaging/application/message_theme_provider.dart (new)
  lib/features/messaging/presentation/widgets/chat_bubble.dart   (edit)
  lib/features/messaging/presentation/widgets/bubble_shapes.dart (new)
  lib/features/settings/presentation/chat_appearance_screen.dart (new)
  lib/l10n/app_en.arb                             (edit)
supabase/
  migrations/210_message_theme_settings.up.sql    (new)
  migrations/210_message_theme_settings.down.sql  (new)
```

## 6. Test Plan

- Unit: provider transitions, persistence.
- Widget golden: all 18 combos x (text, image, video, voice, reply, system) = 108 goldens. Tedious but worth it.
- E2E: pick rounded + tails + cozy, restart, persists.
- Accessibility: tap targets remain ≥44pt across densities.
- Perf: frame budget unchanged on long thread.

## 7. Rollout & Feature Flags

- Flag: `feature.message_themes.enabled`.
- Default OFF initially; current default (square no-tail cozy) maps to existing behavior.
- Beta: 10% rollout 5d.
- Canary 50% → 100%.

## 8. Rollback Plan

1. Disable flag; UI still works at default.
2. No data loss; rows ignored.

## 9. Dependencies / Blockers

- Depends on: existing chat infra.
- Blocks: nothing.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Compact density breaks attachment layout | M | M | golden tests for all kinds |
| Tail painter perf regression | L | M | benchmark on 200-msg thread |
| Density change shifts scroll position | M | L | preserve scroll anchor on theme swap |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] 108 goldens recorded and clean
- [ ] Code merged
- [ ] Zero P0/P1 bugs in 7-day window
