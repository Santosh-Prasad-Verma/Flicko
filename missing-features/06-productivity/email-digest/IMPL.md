# Email Digest — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 1d | PM |
| 1 | Migration 167 + models | 1d | Backend |
| 2 | Ranker + read aggregations | 4d | Backend |
| 3 | MJML template + renderer | 3d | Backend/Design |
| 4 | Resend client + planner cron | 2d | Backend |
| 5 | Preferences UI | 3d | Mobile |
| 6 | Unsubscribe page (web) | 1d | Web |
| 7 | QA, bounce/complaint testing | 3d | QA |
| 8 | Beta -> GA | 21d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/167_email_digest.up.sql`
- [ ] Down migration
- [ ] Models `internal/models/digest.go`
- [ ] Ranker `services/productivity/digest/ranker.go` (mentions, threads, DMs, trending)
- [ ] Template MJML files in `services/productivity/digest/templates/`
- [ ] Renderer compiled at build time -> Go assets
- [ ] Sender wraps Resend client with backoff + adapter interface
- [ ] Planner cron `digest_planner_tick` every 5 min
- [ ] Unsubscribe token signer (JWT) + handler
- [ ] Bounce/complaint webhook handler from Resend
- [ ] Wire routes
- [ ] Audit log
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: ranker fairness, PII leak guard, bounce handling

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/email_digest/`
- [ ] Preferences screen entry point
- [ ] Domain entities
- [ ] Repository
- [ ] Riverpod provider
- [ ] Server allowlist sub-screen
- [ ] Preview render (web view to backend preview endpoint)
- [ ] L10n
- [ ] Tests

## 4. AI / Infra Tasks

- [ ] Resend account + API key in Doppler
- [ ] DNS: SPF, DKIM, DMARC for `flicko.io`
- [ ] SES backup adapter (config behind env)

## 5. Files Touched

```
backend/
  internal/services/productivity/digest/
    planner.go
    ranker.go
    template.go
    sender.go
    unsubscribe.go
    templates/
      digest.mjml
      digest.txt.tmpl
  internal/handlers/digest/
    preferences_handler.go
    unsubscribe_handler.go
    bounce_webhook.go
  internal/models/digest.go
  internal/repo/digest_repo.go
  cmd/server/main.go                     (edit)
  api/openapi.yaml                       (edit)
mobile/
  lib/features/productivity/email_digest/...
  lib/core/router/app_router.dart        (edit)
  lib/l10n/app_en.arb                    (edit)
supabase/
  migrations/167_email_digest.up.sql
  migrations/167_email_digest.down.sql
```

## 6. Test Plan

- Unit: ranker; renderer outputs both HTML + plain text; PII guard tests
- Integration: full plan -> render -> Resend stub -> mark sent
- Litmus: preview email in 12 clients
- Load: 10k subscribers; planner stage drains in <10 min
- A11y: alt text, contrast, plain-text fallback
- Security: unsub token tampering tests

## 7. Rollout & Feature Flags

- Flag `feature.email_digest.enabled`
- Internal -> 1% -> 10% -> 50% -> 100% over 21d
- Kill switch flips flag and pauses cron

## 8. Rollback Plan

1. Flip flag
2. Pause cron
3. Stop sender
4. Tables stay; subscriptions intact

## 9. Dependencies / Blockers

- Depends on: messages, mentions, threads, settings, audit-log
- External: Resend account approved; domain DNS configured

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Spam complaint | M | H | low send volume + opt-in only |
| Resend free quota burn | M | M | per-day cap; SES backup |
| Localization gaps | M | L | English fallback |
| PII in digest | L | H | strict ranker tests |

## 11. Cost Model

| Component | Free tier | $ at 100k DAU |
|-----------|-----------|----------------|
| Resend | 3k/mo free | $20/mo (paid tier) |
| Compute | Railway free | $0 |
| **Total** | | **$0 - $20/mo** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Open rate >= 30% in beta
- [ ] Bounce rate < 2%
- [ ] Beta NPS >= 35
- [ ] Zero P0/P1 in 7d
