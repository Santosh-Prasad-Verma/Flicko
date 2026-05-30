# Animated Server Icons — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 207 | 1d | Backend |
| 2 | Upload + validate handler (GIF resize, Lottie parse) | 4d | Backend |
| 3 | Static fallback derivation worker | 2d | Backend |
| 4 | Mobile sidebar render + cache | 4d | Mobile |
| 5 | Settings toggle + reduced motion | 1d | Mobile |
| 6 | Photosensitive heuristic | 2d | Backend |
| 7 | QA + a11y audit | 2d | QA |
| 8 | Beta | 3d | All |
| 9 | GA | 1d | All |

Total: ~22d.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/207_animated_server_icons.up.sql`.
- [ ] Down migration.
- [ ] Model `backend/internal/models/server_icon.go`.
- [ ] Service `backend/internal/services/icons/service.go`:
  - `UploadAnimated(ctx, serverID, fileBytes, mime)` returns `IconAsset`.
  - `Disable(ctx, serverID)` reverts to static.
- [ ] GIF processor `backend/internal/services/icons/gif_processor.go`:
  - reuses `golang.org/x/image/draw` for resize to 256x256.
  - re-encodes with `gif.EncodeAll` capping frame count and total size.
- [ ] Lottie validator `backend/internal/services/icons/lottie_validator.go`:
  - parses JSON, rejects `expressions` and `scripts` keys, enforces FPS≤60.
- [ ] Photosensitive heuristic `backend/internal/services/icons/photosensitive.go`:
  - GIF: average per-frame luminance delta; flag when ≥3 transitions/sec exceed 25% delta.
  - Lottie: count keyframes per second on opacity/fill nodes.
- [ ] Static fallback worker `backend/internal/jobs/icon_static_fallback.go`:
  - extracts frame 0 → webp 256x256.
- [ ] Handler `backend/internal/handlers/server_icons_handler.go` (`POST /servers/:sid/icon/animated`, `DELETE /servers/:sid/icon/animated`).
- [ ] Wire routes in `backend/cmd/server/main.go`.
- [ ] Centrifugo publish `server:<sid>` event `icon.updated`.
- [ ] Permission middleware: owner or `manage_server`.
- [ ] Audit log entries.

## 3. Mobile Tasks

- [ ] Feature folder reuses `mobile/lib/features/server_settings/`.
- [ ] Provider `mobile/lib/features/server_settings/application/animated_icon_provider.dart`:
  - state: enabled, format (gif|lottie), url.
  - listens to `MediaQuery.disableAnimations`.
- [ ] Widget `mobile/lib/features/shared/presentation/widgets/animated_server_icon.dart`:
  - dispatches between `Lottie.network` and animated `Image.network` based on MIME.
  - pause when off-screen via `VisibilityDetector`.
  - pause when battery saver (cross-platform).
- [ ] Upload UI in `mobile/lib/features/server_settings/presentation/screens/server_appearance_screen.dart`.
- [ ] Tests: widget golden of sidebar with mock animated icon (frozen first frame).
- [ ] L10n keys.

## 4. AI / Infra Tasks

- N/A.

## 5. Files Touched (predicted)

```
backend/
  internal/services/icons/service.go              (new)
  internal/services/icons/gif_processor.go        (new)
  internal/services/icons/lottie_validator.go     (new)
  internal/services/icons/photosensitive.go       (new)
  internal/jobs/icon_static_fallback.go           (new)
  internal/handlers/server_icons_handler.go       (new)
  internal/models/server_icon.go                  (new)
  cmd/server/main.go                              (edit)
mobile/
  lib/features/server_settings/application/animated_icon_provider.dart  (new)
  lib/features/server_settings/presentation/screens/server_appearance_screen.dart (edit/new)
  lib/features/shared/presentation/widgets/animated_server_icon.dart    (new)
  lib/l10n/app_en.arb                             (edit)
supabase/
  migrations/207_animated_server_icons.up.sql     (new)
  migrations/207_animated_server_icons.down.sql   (new)
```

## 6. Test Plan

- Unit: GIF resize bounds, Lottie expression rejection, photosensitive thresholds.
- Integration: upload → validate → static fallback created.
- E2E: server owner uploads `.json`, sidebar animates, member toggles off.
- Load: 200 uploads/min for 5 min, p99 <2s.
- Accessibility: `disableAnimations=true` -> static fallback rendered.
- Security: malicious JSON with `expressions: [...]` rejected.

## 7. Rollout & Feature Flags

- Flag: `feature.animated_icons.enabled`.
- Default OFF in prod.
- Beta: 50 servers.
- Canary 10% → 100% over 5d.

## 8. Rollback Plan

1. Disable flag — clients render static fallback (always present).
2. Stop static-fallback worker.
3. Leave records; no data loss.

## 9. Dependencies / Blockers

- Depends on: existing server settings, Appwrite storage.
- Blocks: nothing.
- External: `lottie` Flutter package.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Battery drain | M | M | pause off-screen + battery saver |
| Photosensitive escape | M | H | conservative threshold + admin override |
| Storage cost spike | L | M | 512KB cap, 1 icon/server |
| Lottie parser CVEs | L | M | strict whitelist, sandboxed parse |
| Sidebar perf regression | L | M | golden + perf benchmark |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| Appwrite | Free 2GB | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] 20 hand-picked Lottie icons published in store-of-defaults
- [ ] Code merged
- [ ] Photosensitive false-positive rate <5%
- [ ] Zero P0/P1 bugs in 7-day window
