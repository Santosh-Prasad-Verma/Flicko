# Multi-Language 50+ — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + Crowdin/Weblate signup + glossary draft | 3d | PM |
| 1 | ARB tooling, pseudo-locale generator, lint for hardcoded strings | 3d | Mobile lead |
| 2 | LocaleProvider, picker UI, Settings screen | 4d | Mobile |
| 3 | Backend `i18n.Lookup`, error-code table, migration 258 | 3d | Backend |
| 4 | AI services accept `target_lang`, prompt template wrap | 3d | AI/Backend |
| 5 | Crowdin sync action, screenshot pipeline | 2d | DevOps |
| 6 | Translate launch 5 (es/pt/fr/de/ja) to 100% via paid bootstrap or community sprint | 7d | Community |
| 7 | QA, accessibility audit, beta | 4d | QA |
| 8 | GA + remaining 45 locales rolling | continuous | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/258_i18n_messages.up.sql` — `i18n_messages` table
- [ ] Down migration
- [ ] Model `backend/internal/models/i18n_message.go`
- [ ] Service `backend/internal/services/i18n/multi-language-50/service.go` with `Lookup(ctx, code, lang) (string, error)`
- [ ] In-memory LRU cache (size 4096) refreshed every 60s from DB
- [ ] Service tests (table-driven, ≥90% cov; fuzz on missing keys)
- [ ] Middleware `backend/internal/middleware/locale.go` — sets `ctx.Value(LangKey)` from `Accept-Language`, profile preference, or query `?lang=`
- [ ] Handler error wrapper `backend/internal/handlers/error_response.go` — picks localized message
- [ ] Wire into AI handlers: `summarize`, `transcribe`, `aura.chat` accept `target_lang`
- [ ] Push-notification builder localizes per recipient
- [ ] Mail-gateway template selector by `recipient.preferred_lang`
- [ ] Audit log entries (no PII, just locale code on access)
- [ ] Metrics: `flicko_i18n_lookup_total{lang,hit}` counter, `flicko_i18n_fallback_total{from,to}` counter
- [ ] OpenAPI: every error response shape gains `lang` field

## 3. Mobile Tasks

- [ ] Confirm `flutter_localizations` + `intl` already in `pubspec.yaml` (they are — version pinned)
- [ ] Update `l10n.yaml` with all 50 locale codes; one ARB per locale
- [ ] Generate stub ARBs from `app_en.arb` via script `scripts/seed_locales.dart`
- [ ] `mobile/lib/core/i18n/locale_provider.dart` — Riverpod `StateNotifierProvider<Locale>`
- [ ] `mobile/lib/core/i18n/locale_resolver.dart` — chain: profile → device → en
- [ ] `mobile/lib/core/i18n/pseudo_locale.dart` — wraps every string, expands ~30%
- [ ] Settings screen `mobile/lib/features/settings/presentation/language_settings_screen.dart`
- [ ] Add to `mobile/lib/core/router/app_router.dart`: route `/settings/language`
- [ ] Hook `LocaleProvider.locale` into `MaterialApp.locale` in `app.dart`
- [ ] Lint custom rule `no_hardcoded_user_facing_strings.dart` in `analysis_options.yaml`
- [ ] Tests: golden test per locale (5 launch locales) for `home_screen`, `settings_screen`
- [ ] Provider tests for `LocaleResolver` chain
- [ ] E2E: Maestro flow verifies pt-BR end-to-end

## 4. AI / Infra Tasks

- [ ] Prompt templates `backend/internal/services/i18n/multi-language-50/prompts/system_<lang>.tmpl`
- [ ] Auto-generate non-en prompts from en master via Groq once, then human-review
- [ ] Cost guardrails: Groq tokens/locale/day capped at 10k
- [ ] Eval harness `backend/internal/services/i18n/multi-language-50/eval/`: 100 golden cases per launch locale; pass criteria = BLEU ≥ 25 AND human review ≥ 4/5

## 5. Files Touched (predicted)

```
backend/
  internal/services/i18n/multi-language-50/service.go        (new)
  internal/services/i18n/multi-language-50/cache.go          (new)
  internal/services/i18n/multi-language-50/prompts/*.tmpl    (new)
  internal/middleware/locale.go                              (new)
  internal/handlers/error_response.go                        (new)
  internal/models/i18n_message.go                            (new)
  internal/handlers/ai/aura_handler.go                       (edit — add target_lang)
  internal/handlers/ai/summarize_handler.go                  (edit)
  cmd/server/main.go                                         (edit)
mobile/
  lib/l10n/app_*.arb                                         (50 new files)
  lib/l10n/l10n.yaml                                         (edit)
  lib/core/i18n/locale_provider.dart                         (new)
  lib/core/i18n/locale_resolver.dart                         (new)
  lib/core/i18n/pseudo_locale.dart                           (new)
  lib/features/settings/presentation/language_settings_screen.dart (new)
  lib/core/router/app_router.dart                            (edit)
  lib/app.dart                                               (edit)
mail-gateway/
  templates/<event>/<lang>.html                              (50 × N new files; non-en seeded from en)
supabase/
  migrations/258_i18n_messages.up.sql                        (new)
  migrations/258_i18n_messages.down.sql                      (new)
.github/
  workflows/crowdin-sync.yml                                 (new)
crowdin/
  crowdin.yml                                                (new)
  glossary.tbx                                               (new)
```

## 6. Test Plan

- Unit: ≥90% on `i18n.Lookup` and `LocaleResolver`
- Integration: Postgres seeded with 5 locales × 200 keys; verify lookup hit/miss/fallback paths
- Golden: 5 launch locales × 5 critical screens = 25 goldens
- Pseudo-locale: layout-stress test; assert no overflow on phones at 320×640
- ARB lint: CI fails if any key in `app_en.arb` lacks at least a Crowdin placeholder in other locales
- Hardcoded-string lint: CI fails on `Text('Hello')` in `lib/features/**`
- Load: k6 — `/api/v1/ai/summarize?target_lang=ja` 100 rps for 5m; p99 < 1.5s
- Accessibility: VoiceOver in es; TalkBack in hi; verify screen reader pronounces correctly
- Security: tabletop — locale header injection (`Accept-Language: en'; DROP TABLE`)

## 7. Rollout & Feature Flags

- Flag: `feature.multi_language_50.enabled` (default OFF until phase 6)
- Per-locale flag: `feature.multi_language_50.locales.<code>` (default OFF until coverage ≥80%)
- Beta cohort: 100 internal accounts forced to non-en locales
- Canary: 1% (locale=pt-BR only) → 10% → 50% → 100% over 10d per launch locale
- Kill switch tested: setting `feature.multi_language_50.enabled=false` reverts whole app to en

## 8. Rollback Plan

1. Disable global flag → all UI returns to en immediately
2. If a single locale's translations are catastrophically wrong, disable that locale's flag
3. Backend: keep `i18n_messages` rows; a buggy translation can be fixed by row update, no migration revert
4. ARB: hot-revert via Crowdin "rollback to last good build" UI

## 9. Dependencies / Blockers

- Depends on: nothing — standalone
- Blocks: `rtl-support` (needs locale codes set), `multi-currency` (uses locale for number format), `local-timezones` (uses locale for date format), `regional-content-filters` (uses locale for compliance copy)
- External: Crowdin OSS plan approval (1-2w lead time); fall back to Weblate

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Crowdin denies OSS plan | Medium | Medium | Weblate self-hosted ready as fallback |
| Volunteer burnout | High | Medium | DeepL MT first draft; recognize contributors in About |
| Plural rules wrong | Medium | High | Strict ICU MessageFormat; CI lint |
| App bundle bloat | Medium | Low | Deferred-load ARB; only ship en + device locale at install |
| Hardcoded strings slip in | High | Medium | Custom Dart analyzer rule blocks merges |
| LLM hallucinates wrong language | Medium | Medium | Eval harness + retry with stricter system prompt |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Crowdin OSS | Yes (open-source plan) | $0 |
| Weblate self-hosted | Yes (Docker on existing infra) | $0 |
| DeepL Free MT | Yes (500k chars/mo) | $0 |
| Storage of 50 ARBs | Trivial | $0 |
| AI translation calls | Groq free tier | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] 5 launch locales at 100%; 45 others at ≥60%
- [ ] Crowdin project public, glossary published
- [ ] CI lint for hardcoded strings green for 30 days
- [ ] Metrics dashboard live (lookup hit rate, fallback rate, per-locale DAU)
- [ ] Beta feedback ≥4.0/5
- [ ] Zero P0/P1 i18n bugs in 7-day window
- [ ] Translator credits visible in app
