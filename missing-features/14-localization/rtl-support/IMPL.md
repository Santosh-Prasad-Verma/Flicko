# RTL Support — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + iconset audit | 2d | Design |
| 1 | Pseudo-RTL infrastructure + golden harness | 2d | Mobile |
| 2 | Root Directionality + MaterialApp wiring | 1d | Mobile |
| 3 | Sweep `lib/features/**` for hardcoded LTR (EdgeInsets, Alignment) | 4d | Mobile (parallelized) |
| 4 | DirectionalIcon + icon migration | 2d | Mobile |
| 5 | BidiText + per-message direction detection (backend + mobile) | 2d | Both |
| 6 | Mail-gateway dir attribute injection | 1d | Backend |
| 7 | Lint rules + CI integration | 1d | DevEx |
| 8 | QA pass with native ar/he/fa/ur reviewers | 3d | QA |
| 9 | Beta + GA | 5d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/259_rtl_support.up.sql` — adds `messages.direction` ENUM
- [ ] Down migration
- [ ] Service `backend/internal/services/i18n/rtl-support/service.go` with `DetectDirection`
- [ ] Wire into `messages_handler.go` insert path
- [ ] Mail-gateway: `mail-gateway/templates/_shared/shell.html` — add `dir="{{.Dir}}"`
- [ ] Mail-gateway: pass `Dir` from recipient.preferred_lang lookup
- [ ] Update OpenAPI: `Message.direction` field
- [ ] Tests: bidi detect table-driven 50+ cases (ar, he, fa, ur, mixed, emoji-only, numbers-only)

## 3. Mobile Tasks

- [ ] `mobile/lib/core/rtl/directional_icon.dart`
- [ ] `mobile/lib/core/rtl/bidi_text.dart`
- [ ] `mobile/lib/core/rtl/pseudo_rtl.dart`
- [ ] `mobile/lib/core/rtl/directional_extensions.dart`
- [ ] Update `mobile/lib/app.dart` — wrap with `Directionality` from `LocaleProvider`
- [ ] Sweep modules (parallel work):
  - [ ] `mobile/lib/features/server_channels/**`
  - [ ] `mobile/lib/features/messages/**`
  - [ ] `mobile/lib/features/voice/**`
  - [ ] `mobile/lib/features/gaming/**`
  - [ ] `mobile/lib/features/ai_assistant/**`
  - [ ] `mobile/lib/features/notifications/**`
  - [ ] `mobile/lib/features/settings/**`
  - [ ] `mobile/lib/core/widgets/**`
- [ ] Replace icons (back/forward/chevron/send/reply) with `DirectionalIcon`
- [ ] Drawer slide-in: flip `SlideTransition` direction based on `Directionality.of(context)`
- [ ] Swipe-to-reply gesture: flip drag direction in RTL
- [ ] Voice channel mute/leave/raise-hand bar — verify mirroring
- [ ] Stage channel speaker arrangement — verify mirroring
- [ ] AI Aura voice screen — verify mirroring
- [ ] Notifications screen — flip leading/trailing widgets
- [ ] Storage settings — donut chart label dir
- [ ] Pseudo-RTL toggle in dev menu
- [ ] Goldens: ar locale × 5 critical screens = 5 (initial; expand to 25 over time)
- [ ] Lint: enable `tools/lints/rtl_safe` in `analysis_options.yaml`

## 4. Files Touched (predicted)

```
backend/
  internal/services/i18n/rtl-support/service.go            (new)
  internal/services/i18n/rtl-support/service_test.go       (new)
  internal/handlers/messages_handler.go                    (edit)
  internal/models/message.go                               (edit — add Direction field)
mail-gateway/
  templates/_shared/shell.html                             (edit — dir attr)
  internal/render.go                                       (edit — pass Dir)
mobile/
  lib/app.dart                                             (edit)
  lib/core/rtl/directional_icon.dart                       (new)
  lib/core/rtl/bidi_text.dart                              (new)
  lib/core/rtl/pseudo_rtl.dart                             (new)
  lib/core/rtl/directional_extensions.dart                 (new)
  lib/features/**/                                         (broad edit sweep)
tools/
  lints/rtl_safe/lib/rtl_safe.dart                         (new)
  lints/rtl_safe/pubspec.yaml                              (new)
supabase/
  migrations/259_rtl_support.up.sql                        (new)
  migrations/259_rtl_support.down.sql                      (new)
test/
  golden/rtl/<screen>_ar.png                               (new)
```

## 5. Test Plan

- Unit (Go): 50+ bidi detection cases.
- Widget (Flutter): `DirectionalIcon` flips correctly in both directions.
- Golden: pseudo-RTL + ar variants for 5 critical screens; CI fails on diff.
- Integration: send a mixed-script message, assert backend persists correct `direction`.
- E2E (Maestro): flow `home → channel → send → reply → react → back` in ar.
- Accessibility: VoiceOver in ar; manual screen-reader pass.
- Performance: Flutter profile build under ar locale; assert no jank delta vs en.

## 6. Rollout & Feature Flags

- Flag: `feature.rtl_support.enabled` (default ON once shipped; off forces LTR even on RTL locales).
- Per-locale flag: not needed — all RTL locales share the same code path.
- Beta cohort: forced ar, he, fa, ur device-locale beta on 100 internal accounts.
- Canary: 1% of RTL locale users → 10% → 50% → 100%.
- Kill switch tested: setting flag false reverts to LTR layout.

## 7. Rollback Plan

1. Disable flag → MaterialApp forces `TextDirection.ltr`.
2. Backend `direction` column stays — no migration revert.
3. Mail-gateway `dir` attr defaults to `ltr` if anything breaks.

## 8. Dependencies / Blockers

- Depends on: `multi-language-50` (we need `i18n_locales.rtl` flag).
- Blocks: nothing.
- External: none.

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hidden hardcoded EdgeInsets break layout | High | Medium | Lint + golden CI |
| 3rd-party widget renders wrong | Medium | Medium | Wrap in scoped Directionality fallback |
| Native QA volunteers disengaged | Medium | High | Crowdin recognition + paid stipend if needed |
| RTL gesture confusion | Low | Medium | Follow platform conventions; test with native users |

## 10. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Bidi detection (in-process) | n/a | $0 |
| Storage of `direction` column | trivial | $0 |
| QA volunteer stipend | optional | up to $200 one-time |
| **Total** | | **$0** target |

## 11. Done Definition

- [ ] All sweep tasks checked
- [ ] Lint rules block hardcoded LTR in features/
- [ ] 25 goldens green for ar locale
- [ ] Native ar/he/fa/ur reviewers signed off
- [ ] Crash parity within 0.1%
- [ ] Zero P0/P1 RTL bugs in 7-day window
