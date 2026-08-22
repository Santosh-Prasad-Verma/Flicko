# Native RTMP Streaming — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + Azure Media Ingress sandbox sign-off | 3 d | PM / Infra |
| 1 | DB schema + migration 230 | 2 d | Backend |
| 2 | Service + ingress provisioning + key rotation | 8 d | Backend |
| 3 | Mobile setup sheet + viewer player | 10 d | Mobile |
| 4 | Webhook reconciliation + Centrifugo wiring | 4 d | Backend |
| 5 | QA + accessibility + load (k6) | 4 d | QA |
| 6 | Beta rollout (1 → 10%) | 7 d | All |
| 7 | GA | 2 d | All |

## 2. Backend Tasks

- [ ] `supabase/migrations/230_native_rtmp_streaming.up.sql`
- [ ] Down migration
- [ ] `backend/internal/models/stream.go` — `Stream`, `StreamKey`, `StreamEvent`, enums.
- [ ] `backend/internal/repo/stream_repo.go` — CRUD + atomic upsert by `(channel_id, state)`.
- [ ] `backend/internal/services/streaming/native_rtmp/service.go`
  - `CreateIngress(ctx, req)` — calls Azure Media Ingress API, hashes key (argon2id), writes `stream_keys` row.
  - `RotateKey(ctx, channelID)` — soft-revokes old, creates new, publishes `stream.key_rotated`.
  - `EndStream(ctx, streamID, reason)`
- [ ] `backend/internal/services/streaming/native_rtmp/health_worker.go` — 15 s tick, reconciles state.
- [ ] `backend/internal/handlers/streaming/native_rtmp_handler.go` — REST routes.
- [ ] `backend/internal/handlers/streaming/azure_acs_webhook.go` — signature verify, idempotency on `(stream_id, kind, occurred_at)`.
- [ ] Service tests (table-driven, ≥85% coverage on argon2id paths).
- [ ] Handler tests with `httptest`.
- [ ] Wire routes in `backend/cmd/server/main.go` under `/api/v1/streams` and `/api/v1/channels/:cid/streams`.
- [ ] Centrifugo channel handler `stream:<id>` — verify membership, throttle to 5 publishes/sec for `viewers`.
- [ ] Permission middleware enforces `stream.publish` and `stream.moderate`.
- [ ] Audit-log writes on key reveal, rotate, revoke.
- [ ] Prometheus counters + histograms.
- [ ] OpenAPI doc updated in `backend/api/openapi.yaml`.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/streaming/native_rtmp/`.
- [ ] Data: `stream_dto.dart`, `stream_repository.dart`, `azure_acs_remote_datasource.dart`, `centrifugo_stream_datasource.dart`.
- [ ] Domain: `stream.dart`, usecases `start_stream`, `get_stream_key`, `rotate_key`, `end_stream`.
- [ ] Application: `stream_provider.dart`, `viewer_provider.dart`, `key_provider.dart`.
- [ ] Presentation: `stream_setup_sheet.dart`, `stream_view_screen.dart`, `live_indicator.dart`, `bitrate_chart.dart`.
- [ ] Routing: register `/stream/:id` and bottom-sheet route in `mobile/lib/core/router/app_router.dart`.
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb`: `stream.go_live`, `stream.live_label`, `stream.error_disconnected`, etc.
- [ ] Tests: provider tests, widget tests for setup sheet, golden tests for live badge.
- [ ] Empty / error / loading states wired.

## 4. AI / Infra Tasks

- [ ] Azure Media Ingress webhook signing key rotated and stored in Doppler.
- [ ] Bunny CDN pull-zone `hls.flicko.app` configured.
- [ ] Cost guardrails: per-server quota of 10 concurrent streams enforced in service.
- [ ] Eval harness skipped — no AI prompts in v1.

## 5. Files Touched (predicted)

```
backend/
  internal/models/stream.go                                   (new)
  internal/repo/stream_repo.go                                (new)
  internal/services/streaming/native_rtmp/service.go          (new)
  internal/services/streaming/native_rtmp/health_worker.go    (new)
  internal/handlers/streaming/native_rtmp_handler.go          (new)
  internal/handlers/streaming/azure_acs_webhook.go              (new)
  cmd/server/main.go                                          (edit)
mobile/
  lib/features/streaming/native_rtmp/...                      (new tree)
  lib/core/router/app_router.dart                             (edit)
supabase/
  migrations/230_native_rtmp_streaming.up.sql                 (new)
  migrations/230_native_rtmp_streaming.down.sql               (new)
```

## 6. Test Plan

- Unit: ≥85% on service.go and key-hash paths.
- Integration: testcontainers Postgres + Redis + a local mock Azure Media Ingress (record / replay HTTP).
- E2E: Maestro flow `stream/go_live.yaml` — open setup, copy key, mock OBS publish, see live state.
- Load: k6 with 200 concurrent streams, 100 viewers each — hold 10 min.
- Accessibility: axe-flutter on viewer + setup screens; manual VoiceOver pass.
- Security: tabletop on key leak, replay, and webhook spoofing.

## 7. Rollout & Feature Flags

- Flag: `feature.native_rtmp_streaming.enabled` (Doppler, per environment).
- Sub-flag: `feature.native_rtmp_streaming.regions` — enable regions individually.
- Default OFF in prod.
- Beta: 10 internal servers + 5 partner streamers.
- Canary: 1% → 10% → 50% → 100% over 14 d.
- Kill switch tested in staging weekly.

## 8. Rollback Plan

1. Disable flag (instant).
2. Stop `health_worker` cron.
3. Revoke all active stream keys (single SQL update).
4. Revert handler routes.
5. Down migration only if data corrupt.

## 9. Dependencies / Blockers

- Depends on: existing Azure ACS Cloud contract, Bunny CDN pull-zone.
- Blocks: `vod-storage`, `clips-system`, `stream-donations`, `stream-analytics`.
- External: Azure Media Ingress feature parity for SRT in `eu-west` (confirmed 2026-Q2).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Azure Media Ingress regional outage | M | H | DNS fail-over + UI banner |
| Stream-key leak | M | H | one-publisher check, auto-revoke |
| HLS egress cost overrun | L | H | per-server quota + Prometheus alert |
| Encoder reconnect storm | L | M | backoff + cap retries |
| Mobile player CPU on low-end | M | M | 480p default ABR on devices <4 GB RAM |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Azure ACS SFU | partial | $1,200 / mo |
| Azure Media Ingress | partial | $400 / mo |
| Bunny CDN | none | $900 / mo |
| R2 (no VOD here) | yes | $0 |
| **Total** | | **~$2,500 / mo** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Code merged to main.
- [ ] In-tree spec updated (this file + INDEX status).
- [ ] Grafana board live; alerts wired.
- [ ] Beta feedback ≥4.0 / 5.
- [ ] Zero P0 / P1 bugs in 14-day window.
