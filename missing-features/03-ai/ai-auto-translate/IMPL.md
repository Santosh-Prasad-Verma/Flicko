# Auto-Translate — Inline Per-Message Translation — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 1d | PM/Design |
| 1 | DB migration `132_ai_translate` | 1d | Backend |
| 2 | LibreTranslate self-host + DeepL client | 2d | Backend |
| 3 | LID + glossary mask/unmask | 2d | Backend |
| 4 | Service + handler + cache | 3d | Backend |
| 5 | Mobile inline button + bubble | 3d | Mobile |
| 6 | Settings + glossary admin screens | 2d | Mobile |
| 7 | Eval (60-pair golden) | 2d | Backend |
| 8 | QA + a11y | 2d | QA |
| 9 | Beta + GA | 5d | All |

Total: ~21 dev days.

## 2. Backend Tasks

- [ ] `supabase/migrations/132_ai_translate.up.sql` (+ down)
- [ ] `backend/internal/models/ai_translate.go`
- [ ] `backend/internal/repo/ai_translate_repo.go`
- [ ] `backend/internal/services/ai/auto_translate/lid.go` — whatlanggo wrapper
- [ ] `backend/internal/services/ai/auto_translate/libre_client.go` — HTTP client (`/translate`, `/languages`, `/health`)
- [ ] `backend/internal/services/ai/auto_translate/deepl_client.go` — HTTP client w/ quota counter
- [ ] `backend/internal/services/ai/auto_translate/router.go` — pair routing logic
- [ ] `backend/internal/services/ai/auto_translate/glossary.go` — case-sensitive word-boundary regex
- [ ] `backend/internal/services/ai/auto_translate/cache.go`
- [ ] `backend/internal/services/ai/auto_translate/ratelimit.go`
- [ ] `backend/internal/services/ai/auto_translate/service.go` — orchestrator
- [ ] `backend/internal/services/ai/auto_translate/warmer.go`
- [ ] `backend/internal/handlers/ai_translate_handler.go`
- [ ] Wire routes in `main.go`
- [ ] Audit log: `ai.translate.invoked` (sampled 1%)
- [ ] Prometheus metrics in `internal/metrics/ai_translate.go`
- [ ] OpenAPI doc
- [ ] Eval harness `evals/run.go` + `golden.jsonl` (60 pairs across 12 languages)

## 3. Mobile Tasks

- [ ] `mobile/lib/features/ai_assistant/translate/data/translate_repository.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/data/dto/*.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/domain/translation.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/application/translate_provider.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/application/user_lang_pref_provider.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/presentation/translate_inline_button.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/presentation/translation_bubble_overlay.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/presentation/translate_settings_screen.dart`
- [ ] `mobile/lib/features/ai_assistant/translate/presentation/glossary_admin_screen.dart`
- [ ] Hook into `chat_bubble.dart`
- [ ] Routing: `/settings/translate`, `/server/:id/translate/glossary`
- [ ] L10n keys in `app_en.arb`
- [ ] Tests: widget for `TranslationBubble`, provider, glossary editor goldens

## 4. AI / Infra Tasks

- [ ] LibreTranslate Docker on Hetzner-EU and Hetzner-US (4GB RAM, top-30 lang pairs preloaded)
- [ ] DeepL key in Doppler `DEEPL_API_KEY`
- [ ] fastText `lid.176.bin` baked into backend image
- [ ] Prompt convention N/A (not LLM)
- [ ] Cost guardrails:
  - per-user 1000/day
  - per-server 50000/day
  - DeepL daily char-count alert at 80% of free quota (400k of 500k)
- [ ] Eval harness (60 source/reference pairs across en/es/ja/de/fr/pt/ko/zh/hi/ar/ru/it):
  - BLEU-2 ≥0.62 vs reference
  - LID accuracy ≥98%
  - Glossary preservation 100%
  - Roundtrip emoji preservation 100%

## 5. Files Touched

```
backend/
  cmd/server/main.go                                              (edit)
  internal/handlers/ai_translate_handler.go                       (new)
  internal/models/ai_translate.go                                 (new)
  internal/repo/ai_translate_repo.go                              (new)
  internal/services/ai/auto_translate/service.go                  (new)
  internal/services/ai/auto_translate/lid.go                      (new)
  internal/services/ai/auto_translate/libre_client.go             (new)
  internal/services/ai/auto_translate/deepl_client.go             (new)
  internal/services/ai/auto_translate/router.go                   (new)
  internal/services/ai/auto_translate/glossary.go                 (new)
  internal/services/ai/auto_translate/cache.go                    (new)
  internal/services/ai/auto_translate/ratelimit.go                (new)
  internal/services/ai/auto_translate/warmer.go                   (new)
  internal/services/ai/auto_translate/evals/run.go                (new)
  internal/services/ai/auto_translate/evals/golden.jsonl          (new)
  internal/metrics/ai_translate.go                                (new)
  docs/openapi/ai_translate.yaml                                  (new)
  Dockerfile                                                      (edit: COPY lid.176.bin)

mobile/
  lib/features/ai_assistant/translate/data/translate_repository.dart           (new)
  lib/features/ai_assistant/translate/data/dto/*.dart                          (new)
  lib/features/ai_assistant/translate/domain/translation.dart                  (new)
  lib/features/ai_assistant/translate/application/*.dart                       (new)
  lib/features/ai_assistant/translate/presentation/*.dart                      (new)
  lib/features/server_channels/text/presentation/widgets/chat_bubble.dart      (edit)
  lib/core/router/app_router.dart                                              (edit)
  lib/l10n/app_en.arb                                                          (edit)

supabase/
  migrations/132_ai_translate.up.sql                              (new)
  migrations/132_ai_translate.down.sql                            (new)

infra/
  k8s/libretranslate-eu.yaml                                      (new)
  k8s/libretranslate-us.yaml                                      (new)
```

## 6. Test Plan

- Unit: ≥80% on `glossary`, `router`, `cache`, `lid`, `service`
- Integration: testcontainer LibreTranslate + Redis + Postgres
- Eval: nightly CI gate
- E2E (Maestro): `translate_happy.yaml` — long-press JP message, assert bubble shows
- Load: k6 — 200 rps for 5 min; assert p95 <900ms (cache miss)
- Accessibility: axe + screen reader announcement test
- Security:
  - SQL injection in glossary terms
  - Glossary placeholder spoofing (input contains `__GLO_<n>__`) — sanitized
  - XSS via translated text rendering — Flutter Text widget escapes by default

## 7. Rollout & Feature Flags

- Flag: `feature.ai_auto_translate.enabled`
- Per-server toggle in `translate_server_settings.enabled`
- Beta: 5% then 25% then 100%
- Auto-translate behavior defaults to `ask`

## 8. Rollback Plan

1. Doppler flag → 503
2. Remove inline button via remote config
3. LibreTranslate replicas scale to 0 (cost saving, even at $0)
4. Tables retained

## 9. Dependencies / Blockers

- Depends on: existing message store, server settings infra
- Blocks: nothing
- External: DeepL Free tier rate limits

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| LibreTranslate quality complaints | Med | Low | Route top pairs to DeepL when quota allows |
| DeepL terms-of-service forbid caching | Low | Med | Free TOS allows caching for 6 months |
| LID misdetect on short text | Med | Low | Suppress button if <8 chars |
| Glossary collision | Low | Low | word-boundary regex + case-sensitive |
| Quota abuse | Med | Med | per-user + per-server caps + abuse score |

## 11. Cost Model

| Component | Free tier? | $ at 100k DAU |
|-----------|-----------|---------------|
| LibreTranslate (2× 4GB on Hetzner) | self-host | $0 (existing nodes) |
| DeepL Free | 500k chars/mo | $0 (≈80% in cache, well under) |
| fastText LID | local | $0 |
| Postgres (~10MB/mo) | Supabase free | $0 |
| Redis | shared | $0 |
| **Total** | | **$0/mo** target |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Migration applied prod
- [ ] Eval CI green 7 nights
- [ ] Grafana board live
- [ ] Beta feedback ≥4.0/5
- [ ] `INDEX.md` flipped to shipped
