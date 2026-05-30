# [Feature Name] — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration | 1d | Backend |
| 2 | Backend service + handlers | __d | Backend |
| 3 | Mobile UI scaffolding | __d | Mobile |
| 4 | Wire-up + realtime | __d | Both |
| 5 | QA + accessibility audit | 2d | QA |
| 6 | Beta rollout | 3d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration file `supabase/migrations/<NNN>_<feature>.up.sql`
- [ ] Down migration
- [ ] Model `backend/internal/models/<feature>.go`
- [ ] Service `backend/internal/services/<feature>_service.go`
- [ ] Service tests (table-driven, ≥80% cov)
- [ ] Handler `backend/internal/handlers/<feature>_handler.go`
- [ ] Handler tests
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo channel hookup
- [ ] Permission middleware
- [ ] Audit log entries
- [ ] Metrics counters
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/<feature>/`
- [ ] Data: dto + repository + datasource
- [ ] Domain: entity + usecases
- [ ] Application: Riverpod providers
- [ ] Presentation: screens + widgets
- [ ] Routing: add to `app_router.dart`
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb`
- [ ] Tests: widget + provider + golden
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks (if applicable)

- [ ] Ollama / Groq / Whisper setup
- [ ] Prompt templates in `backend/internal/services/<feature>/prompts/`
- [ ] Cost guardrails (per-user/day caps)
- [ ] Eval harness with golden cases

## 5. Files Touched (predicted)

```
backend/
  internal/services/<feature>_service.go        (new)
  internal/handlers/<feature>_handler.go        (new)
  internal/models/<feature>.go                  (new)
  cmd/server/main.go                            (edit)
mobile/
  lib/features/<feature>/...                    (new tree)
  lib/core/router/app_router.dart               (edit)
supabase/
  migrations/<NNN>_<feature>.up.sql             (new)
  migrations/<NNN>_<feature>.down.sql           (new)
```

## 6. Test Plan

- Unit: ≥80% on new code
- Integration: Postgres + Redis + Centrifugo via testcontainers
- E2E: Maestro / Patrol flow
- Load: k6 — hold __ rps for 5m
- Accessibility: axe + manual screen reader pass
- Security: tabletop threat model; auth/authz tests

## 7. Rollout & Feature Flags

- Flag: `feature.<slug>.enabled` (Doppler / config)
- Default OFF in prod
- Beta: 10 internal servers
- Canary: 1% → 10% → 50% → 100% over 7d
- Kill switch tested in staging

## 8. Rollback Plan

1. Disable flag (instant)
2. Stop background workers
3. Revert handler routes
4. Down migration only if data is corrupt — otherwise leave tables (cheap)

## 9. Dependencies / Blockers

- Depends on: __
- Blocks: __
- External: __

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| __ | __ | __ | __ |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| AI | Groq free | $0 |
| Storage | Appwrite free | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] Docs in-tree updated (this file + INDEX status)
- [ ] Metrics dashboard live
- [ ] Beta feedback ≥4.0/5
- [ ] Zero P0/P1 bugs in 7-day window
