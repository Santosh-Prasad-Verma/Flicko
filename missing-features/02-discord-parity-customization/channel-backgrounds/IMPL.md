# Channel Backgrounds — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, design review, libvips spike | 2d | PM/Design + 1 BE |
| 1 | DB migration `126_channel_backgrounds` | 1d | Backend |
| 2 | Image processor library wrapper + tests | 2d | Backend |
| 3 | Service + handler + permissions wiring | 2d | Backend |
| 4 | Variant worker + NATS subjects + idempotency | 1.5d | Backend |
| 5 | Appwrite bucket policies + cleanup cron | 0.5d | Backend |
| 6 | Mobile feature folder + repository | 1d | Mobile |
| 7 | Mobile upload screen + crop/focus | 1.5d | Mobile |
| 8 | Mobile background renderer + BlurHash | 1.5d | Mobile |
| 9 | Member opacity sheet + global toggle | 1d | Mobile |
| 10 | QA + load + a11y audit | 2d | QA |
| 11 | Beta → GA rollout | 5d | All |

Total: ~21 working days.

## 2. Backend Tasks

- [ ] Migration file `supabase/migrations/126_channel_backgrounds.up.sql`.
- [ ] Down migration.
- [ ] Model `backend/internal/models/channel_background.go` (struct + JSON tags + DTO `ChannelBackgroundDTO`).
- [ ] Repo `backend/internal/repo/channel_background_repo.go` (Get, Upsert, Delete, ListPending).
- [ ] Service `backend/internal/services/channel_background_service.go`.
- [ ] Image processor wrapper `backend/internal/services/channel_background/imageproc.go` using `govips`.
- [ ] BlurHash encoder helper.
- [ ] SHA256 + safe-browsing integration via existing `services/safe_browsing_service.go`.
- [ ] Variant worker `backend/internal/services/channel_background/variant_worker.go`.
- [ ] Blob-cleanup worker `backend/internal/services/channel_background/blob_cleanup_worker.go`.
- [ ] Service tests (table-driven, ≥80% cov; mock Appwrite).
- [ ] Handler `backend/internal/handlers/channel_background_handler.go` (POST, GET, DELETE).
- [ ] Handler tests (multipart fixtures + permission matrix).
- [ ] Wire routes in `backend/cmd/server/main.go`.
- [ ] Centrifugo channel hookup — publish `channel.background.updated`/`deleted` on existing `channel:{id}` topic.
- [ ] Permission middleware: reuse `RequireChannelPermission(MANAGE_CHANNEL)`.
- [ ] Audit log entries on upload/delete.
- [ ] Prometheus counters + histograms.
- [ ] OpenAPI doc update.
- [ ] Rate-limit policy in `backend/internal/handlers/middleware.go`: 5 / channel / hour.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/channel_backgrounds/`.
- [ ] Data: `channel_background_dto.dart`, `channel_background_repository.dart`, `channel_background_remote_datasource.dart`.
- [ ] Domain: `channel_background.dart`, `background_opacity.dart`, `image_validation.dart`.
- [ ] Application: `channel_background_provider.dart`, `background_opacity_provider.dart`, `backgrounds_enabled_provider.dart`.
- [ ] Presentation: `background_upload_screen.dart`, `background_focus_picker.dart`, `opacity_sheet.dart`, `channel_background_layer.dart`.
- [ ] Widgets: BlurHash placeholder using `flutter_blurhash`, fade-in `AnimatedSwitcher`.
- [ ] Wire into `mobile/lib/features/server_channels/.../channel_screen.dart` — wrap message list `Stack` with `ChannelBackgroundLayer`.
- [ ] Wire admin entry into `mobile/lib/features/server_settings/...` channel-settings flow.
- [ ] Wire member entry into chat top-bar overflow menu.
- [ ] Add to `mobile/lib/core/router/app_router.dart` route `/servers/:sid/channels/:cid/settings/background`.
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (~16 strings).
- [ ] Honor `MediaQuery.disableAnimations` and `Connectivity.isMetered`.
- [ ] Tests:
  - widget: `background_upload_screen_test.dart`,
  - widget: `channel_background_layer_test.dart`,
  - provider: `channel_background_provider_test.dart`,
  - golden: dark / light / AMOLED, with and without background.
- [ ] States: empty, loading (skeleton), uploading (progress), processing (banner), ready, error, moderated, paywall (n/a v1), data-saver.

## 4. AI / Infra Tasks

- [ ] Appwrite bucket `channel-backgrounds` with policies.
- [ ] Cloudflare in front for CDN egress savings.
- [ ] NATS subjects:
  - `flicko.channel_background.process` (variants),
  - `flicko.channel_background.delete_blobs`.
- [ ] Grafana dashboard `channel_backgrounds`.
- [ ] Sentry tagging + alerts.

## 5. Files Touched (predicted)

```
backend/
  internal/models/channel_background.go                          (new)
  internal/repo/channel_background_repo.go                       (new)
  internal/services/channel_background_service.go                (new)
  internal/services/channel_background_service_test.go           (new)
  internal/services/channel_background/imageproc.go              (new)
  internal/services/channel_background/imageproc_test.go         (new)
  internal/services/channel_background/variant_worker.go         (new)
  internal/services/channel_background/blob_cleanup_worker.go    (new)
  internal/handlers/channel_background_handler.go                (new)
  internal/handlers/channel_background_handler_test.go           (new)
  internal/handlers/middleware.go                                (edit, rate limit)
  cmd/server/main.go                                             (edit)
mobile/
  lib/features/channel_backgrounds/...                           (new tree)
  lib/features/server_channels/.../channel_screen.dart           (edit)
  lib/features/server_settings/.../channel_settings_screen.dart  (edit)
  lib/core/router/app_router.dart                                (edit)
  lib/l10n/app_en.arb                                            (edit)
  test/features/channel_backgrounds/...                          (new)
supabase/
  migrations/126_channel_backgrounds.up.sql                      (new)
  migrations/126_channel_backgrounds.down.sql                    (new)
```

## 6. Test Plan

- Unit: imageproc ≥85%; service ≥80%; provider ≥85%.
- Integration: Postgres + Appwrite (containerized) + NATS (testcontainers) — full upload→worker→ready cycle.
- Golden: rendered chat with 4 sample backgrounds × 4 themes.
- E2E (Patrol): admin uploads, member opens channel, sees image, opens sheet, dims to 0%.
- Load: k6 — 5 uploads/s sustained for 5 min; verify worker queue drains within 30s of stop.
- Chaos: kill worker mid-job; row stays `processing`; reprocess endpoint heals.
- Accessibility: TalkBack/VoiceOver flow — semantics excluded; opacity slider announces percentage.
- Security: malformed multipart, non-image with image MIME, exif-bomb, EXIF GPS scrubbing on `original` upload.
- Storage: confirm orphaned blobs cleaned within 24h.

## 7. Rollout & Feature Flags

- Flag: `feature.channel_backgrounds.enabled` (Doppler / `flicko_feature_flags`).
- Default OFF in prod.
- Beta cohort: 3 internal staff servers + 30 invited servers.
- Canary: 1% of servers (24h) → 10% (24h) → 50% (24h) → 100% over 4 days.
- Per-server kill switch: existing `server_settings.feature_overrides` allows owner to disable.
- Member kill switch: `user_settings.channel_backgrounds_enabled = false`.

## 8. Rollback Plan

1. Disable global flag — admin upload UI hides; existing backgrounds keep rendering server-side until cache expires.
2. If image-processing regression: stop variant worker; mark `processing` rows as `original_only`.
3. If storage abuse: pause uploads via flag; existing rows untouched.
4. Down migration only on data-loss incident; orphaned Appwrite files cleaned by 24h cron.

## 9. Dependencies / Blockers

- Depends on: Appwrite storage (live), Centrifugo (live), NATS (live), `safe_browsing_service` hash list, `permissions_service` channel-level permissions function.
- Blocks: nothing critical; feature is additive.
- External: libvips system package on Railway image (already present).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| libvips OOM on huge image | M | M | Pre-flight dimension cap; hard timeout 8s on processing |
| Egress cost spikes | M | H | Cloudflare CDN; per-server upload cap; mobile variant default |
| Inappropriate content slips past hash check | L | H | Manual report flow; mod queue |
| Visual regression on low-end Android | M | M | RepaintBoundary; BlurHash-only fallback if FPS <30 |
| User confusion (background looks broken on first paint) | L | L | BlurHash placeholder always visible immediately |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU / 5k servers |
|-----------|-----------|--------------------------------------|
| Compute (POST + worker) | Railway free | $0 (low rps) |
| Postgres rows + indexes | Supabase free | $0 (<100MB) |
| Appwrite storage | Appwrite free | $0 (~50GB at 5k channels × 4 variants × 250KB) |
| Egress | Cloudflare free | $0 (cached aggressively) |
| **Total** | | **<$1/mo** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Migration applied to staging and dogfood.
- [ ] Code merged to main behind flag.
- [ ] Variant worker drains under load test.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥ 4.0/5 (n ≥ 30 admins, n ≥ 100 members).
- [ ] Zero P0/P1 bugs in 7-day beta window.
- [ ] L10n strings translated for the top 6 locales.
- [ ] Storage growth tracked; alert at 70% bucket capacity configured.
