# Regional Voice Servers — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, choose Cloud vs self-host | 3d | Infra/PM |
| 1 | Provision na-east + na-west clusters | 3d | Infra |
| 2 | Health check + Cloudflare Worker | 2d | Infra |
| 3 | Migration 263 + voice_regions tables | 1d | Backend |
| 4 | Region picker library + tests | 3d | Backend |
| 5 | Token issuer + session create/join handlers | 3d | Backend |
| 6 | Mobile ping test + region picker provider | 2d | Mobile |
| 7 | Voice settings UI + quality banner | 2d | Mobile |
| 8 | Add eu-west; enable cross-region federation | 4d | Infra+Backend |
| 9 | Add ap-southeast, ap-south, sa-east | 6d | Infra |
| 10 | Failover drill + chaos tests | 2d | All |
| 11 | Beta + GA per region | 2w | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/263_regional_voice_servers.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/voice_region.go`, `voice_session.go`, `voice_session_metric.go`
- [ ] Service `backend/internal/services/i18n/regional-voice-servers/service.go`
- [ ] Picker `backend/internal/services/i18n/regional-voice-servers/picker.go`
- [ ] Health worker `backend/internal/services/i18n/regional-voice-servers/health_worker.go`
- [ ] Sessions handler `backend/internal/handlers/voice/sessions_handler.go`
- [ ] Regions handler `backend/internal/handlers/voice/regions_handler.go`
- [ ] Token mint via Azure ACS SDK (`azure_acs-server-sdk-go`)
- [ ] Failover endpoint `POST /sessions/:id/failover`
- [ ] Server admin pin endpoint
- [ ] User pin endpoint
- [ ] Tests: ≥85% on picker
- [ ] Metrics + dashboards
- [ ] OpenAPI doc

## 3. Mobile Tasks

- [ ] `mobile/lib/core/voice/ping/ping_test.dart`
- [ ] `mobile/lib/core/voice/data/voice_region_repository.dart`
- [ ] `mobile/lib/core/voice/application/region_picker_provider.dart`
- [ ] `mobile/lib/core/voice/application/voice_session_provider.dart` (uses `azure_communication_calling`)
- [ ] `mobile/lib/core/voice/presentation/voice_settings_screen.dart`
- [ ] `mobile/lib/core/voice/presentation/quality_banner.dart`
- [ ] Wire into existing voice channel screen `mobile/lib/features/server_channels/voice/`
- [ ] Settings: `mobile/lib/features/settings/presentation/voice_settings_screen.dart`
- [ ] Tests: provider tests for picker on synthetic scores
- [ ] E2E: join voice; assert chosen region matches expected

## 4. Infra Tasks

- [ ] Terraform module `infra/azure_acs/<region>/`
  - cluster (Hetzner k8s or Azure ACS Cloud project per region)
  - ingress + TLS via Let's Encrypt
  - per-region Redis
  - secrets (Azure ACS API key/secret)
- [ ] DNS: `<region>.voice.flicko.app` → ingress
- [ ] Cloudflare Worker `cf/voice-health/index.ts` for health-check fanout
- [ ] Monitoring: Prometheus federation across regions
- [ ] Runbook: "How to drain a region", "How to add a new region"

## 5. Files Touched (predicted)

```
backend/
  internal/services/i18n/regional-voice-servers/service.go    (new)
  internal/services/i18n/regional-voice-servers/picker.go     (new)
  internal/services/i18n/regional-voice-servers/health_worker.go (new)
  internal/handlers/voice/sessions_handler.go                 (new)
  internal/handlers/voice/regions_handler.go                  (new)
  internal/models/voice_region.go                             (new)
  internal/models/voice_session.go                            (new)
  cmd/server/main.go                                          (edit — register routes + worker)
mobile/
  lib/core/voice/...                                          (new tree)
  lib/features/server_channels/voice/...                      (edit)
  lib/features/settings/presentation/voice_settings_screen.dart (new)
  pubspec.yaml                                                 (edit — add azure_communication_calling)
infra/
  azure_acs/na-east/...                                         (new)
  azure_acs/na-west/...                                         (new)
  azure_acs/eu-west/...                                         (new)
  azure_acs/ap-southeast/...                                    (new)
  azure_acs/ap-south/...                                        (new)
  azure_acs/sa-east/...                                         (new)
cf/
  voice-health/index.ts                                       (new)
supabase/
  migrations/263_regional_voice_servers.up.sql                (new)
  migrations/263_regional_voice_servers.down.sql              (new)
```

## 6. Test Plan

- Unit: picker — synthetic scores, edge cases (single participant, all-same-RTT, partial failure).
- Property: monotonic improvement — adding a faster region should never worsen aggregate score.
- Integration: spin Azure ACS dev; assert token works; assert federation across two dev clusters.
- E2E: Maestro flow joins voice in 3 different region overrides; verify metric exposed.
- Chaos: kill one region in staging; assert next-best chosen and failover time < 5s.
- Load: k6 — 1000 concurrent joins; observe p99 connect time.

## 7. Rollout & Feature Flags

- Flag: `feature.regional_voice_servers.enabled` (default OFF; rolling on per region as it goes live)
- Per-region flag: `feature.regional_voice_servers.regions.<code>.enabled`
- Phase 1: na-east only (current behavior)
- Phase 2: na-east + na-west, no federation
- Phase 3: + eu-west, federation enabled
- Phase 4: APAC + LATAM
- GA when all 6 regions stable for 7 days

## 8. Rollback Plan

1. Disable global flag → all sessions land on na-east (current).
2. Per-region drain → no new sessions land in that region; existing sessions complete.
3. If federation breaks: disable federation flag, fall back to single-region picks.
4. DB rollback: keep `voice_regions` rows; toggle `enabled=false` for problematic ones.

## 9. Dependencies / Blockers

- Depends on: `multi-language-50` (region defaults), existing voice channel feature.
- Blocks: nothing critical.
- External: Azure ACS Cloud account upgrade for federation; Cloudflare Workers free tier.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cost overrun on Azure ACS Cloud | Medium | Medium | Plan self-host migration path (Hetzner) |
| Federation flakiness | Medium | High | Phase rollout; fallback to single-region picks |
| BGP routing surprise | Low | Medium | Multi-region health check from multiple datacenters |
| User confusion over manual region pin | Low | Low | Clear UX copy; default Auto |
| Data residency conflict (KR, EU) | Medium | High | Region opt-in for data-residency-strict users |

## 11. Cost Model

| Component | Free? | Estimated $ at 100k DAU |
|-----------|-------|--------------------------|
| Azure ACS Cloud Build plan | starts $50/mo + usage | ~$300/mo realistic |
| Self-host on Hetzner (alt) | ~$60/mo per region × 6 | $360/mo |
| Cloudflare Workers | free tier | $0 |
| TURN bandwidth | included w/ Azure ACS | $0 |
| Redis per region | shared with existing | $0 |
| **Total (Azure ACS Cloud)** | | **~$300/mo** |

## 12. Done Definition

- [ ] All sweep tasks done
- [ ] 6 regions live and healthy 7 days
- [ ] Median voice p50 < 100ms globally
- [ ] Auto-failover < 5s in chaos tests
- [ ] Voice complaint volume down 70% vs baseline
- [ ] Beta feedback ≥4.0/5
- [ ] Zero P0/P1 voice bugs in 14-day window
- [ ] Runbook for adding/removing regions tested
