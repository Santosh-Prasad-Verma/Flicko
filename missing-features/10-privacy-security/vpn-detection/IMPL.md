# VPN Detection — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + provider sign-up | 1d | PM |
| 1 | DB migration 219 + salt rotation | 1d | Backend |
| 2 | Provider integration + cache | 3d | Backend |
| 3 | Auth-pipeline hook | 2d | Backend |
| 4 | Mobile warning banner + explainer | 2d | Mobile |
| 5 | T&S dashboard tile | 2d | Backend/Web |
| 6 | QA + provider failover test | 2d | QA |
| 7 | Beta | 3d | All |
| 8 | GA | 1d | All |

Total: ~15 working days, 1 backend + 1 mobile + 1 PM.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/219_vpn_detection.up.sql`.
- [ ] Down migration.
- [ ] Models `internal/models/auth_security.go`.
- [ ] Service `internal/services/privacy/vpn_detection/service.go`.
- [ ] Provider abstraction + 2 impls + Noop.
- [ ] Cache layer with daily-salt-aware key.
- [ ] Auth-pipeline middleware: after auth success, run detector and attach to response.
- [ ] T&S dashboard backing API.
- [ ] Audit-log entries.
- [ ] Metrics.
- [ ] OpenAPI doc update.
- [ ] Service tests (≥85%).
- [ ] Failover test: simulate provider 429 → MaxMind picks up.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/privacy/vpn_detection/`.
- [ ] Application: `vpnDetectionProvider` reads from auth-response cache.
- [ ] Presentation: `VpnWarningBanner`, `VpnExplainerSheet`.
- [ ] Patch login/signup screens to render banner if `security.vpn_detected == true`.
- [ ] L10n keys.
- [ ] Tests.

## 4. AI / Infra Tasks

- [ ] None.

## 5. Files Touched (predicted)

```
backend/
  internal/services/privacy/vpn_detection/service.go              (new)
  internal/services/privacy/vpn_detection/provider.go             (new)
  internal/services/privacy/vpn_detection/vpnapi_provider.go      (new)
  internal/services/privacy/vpn_detection/maxmind_provider.go     (new)
  internal/services/auth/login_handler.go                         (edit)
  internal/services/auth/signup_handler.go                        (edit)
  internal/models/auth_security.go                                (new)
  cmd/server/main.go                                              (edit)
mobile/
  lib/features/privacy/vpn_detection/...                          (new tree)
  lib/features/auth/presentation/login_screen.dart                (edit)
  lib/features/auth/presentation/signup_screen.dart               (edit)
supabase/
  migrations/219_vpn_detection.up.sql                             (new)
  migrations/219_vpn_detection.down.sql                           (new)
```

## 6. Test Plan

- **Unit:** detect cache hit/miss; salt rotation correctness; hash determinism.
- **Integration:** mock VPNAPI (httpmock) + Redis testcontainer; full path.
- **E2E:** login from a known VPN exit → banner appears; from clean IP → no banner.
- **Failover:** kill VPNAPI mock → service silently uses MaxMind.
- **Privacy tests:** scan logs for raw IPs; expect zero hits.
- **Load:** 500 logins/sec; cache hit ratio measured.

## 7. Rollout & Feature Flags

- Flag: `feature.vpn_detection.enabled` (Doppler).
- Beta: 10% of logins.
- Canary: 50% over 5d.

## 8. Rollback Plan

1. Disable flag — detector returns "unavailable" and no banner.
2. Existing rows kept; nothing to roll back.

## 9. Dependencies / Blockers

- VPNAPI free-tier API key.
- MaxMind GeoIP2 Anonymous-IP DB license.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Free-tier quota exhausted | Med | Low | failover + alert |
| Raw IP leaks into logs | Low | High | redactor middleware + grep CI test |
| False positives at scale | Med | Low | non-accusatory copy |
| Provider data quality varies | Med | Low | dual-provider sanity check |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| VPNAPI | 1k/day free | $0 (cache makes this fit) |
| MaxMind self-host | $0 (DB only) | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Privacy-policy update.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥4.0/5.
