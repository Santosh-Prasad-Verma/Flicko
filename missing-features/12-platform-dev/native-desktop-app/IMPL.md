# Native Desktop App — Implementation

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + Tauri vs pure Flutter desktop choice | 3 |
| 1 | Tauri 2.x scaffold + bundled Flutter web build | 5 |
| 2 | Native push (APNs/FCM via Tauri plugin or service) | 4 |
| 3 | Auto-updater (signed releases) | 3 |
| 4 | Native menu bar / tray / system shortcuts | 3 |
| 5 | Code-signing pipeline (mac dev id, win EV, linux GPG) | 4 |
| 6 | Backend release manifest + telemetry | 2 |
| 7 | QA across mac/win/linux | 5 |
| 8 | Beta + GA | 5 |

## Backend
- [ ] `supabase/migrations/248_desktop_releases.up.sql`
- [ ] `backend/internal/services/platform/desktop/service.go`
- [ ] `backend/internal/handlers/desktop_release_handler.go` (GET /desktop/update, GET /desktop/releases)
- [ ] CI publishes signed bundles to Cloudflare R2; updates `desktop_releases`
- [ ] Telemetry ingest endpoint (lightweight; rate-limited)

## Desktop
- `desktop/` directory at repo root.
- Tauri 2.x in Rust.
- Bundles Flutter web build from `mobile/build/web` as the renderer.
- Native plugins:
  - `tauri-plugin-updater`
  - `tauri-plugin-notification`
  - `tauri-plugin-deep-link` for `flicko://`
  - `tauri-plugin-shell` for `start` actions
- Custom plugin `voice-bridge` to expose Azure ACS Rust SDK directly (lower CPU than browser WebRTC).

## CI/CD
- GitHub Actions: build mac arm64+x86_64, win x86_64, linux x86_64.
- Notarize mac with Developer ID; sign win with EV cert; AppImage + .deb + .rpm for linux.
- Uploads to R2; updates manifest table via service-role API.

## Files
```
desktop/                                         (new tree)
backend/internal/services/platform/desktop/...   (new)
backend/internal/handlers/desktop_release_handler.go (new)
.github/workflows/desktop-release.yml            (new)
supabase/migrations/248_desktop_releases.up.sql  (new)
```

## Test Plan
- Cold-start time: <1s on M1 / Win 11 / Ubuntu 22.04.
- Bundle size: ≤ 25 MB installed.
- Memory: ≤ 200 MB idle.
- Auto-update: rollback test if hash mismatch.
- Push: tested on all three OSes.
- Deep links: `flicko://server/<id>` opens correctly.

## Rollout
- Flag `feature.desktop_v2.enabled`. Beta channel first.
- Migration path from any prior Electron build (if exists): show banner "New Flicko desktop is available".

## Risks
| Risk | Mitigation |
|------|------------|
| Code-sign cert revoked | secondary CI key; doc rotation playbook |
| Tauri WebView2 mismatch on win | bundle WebView2 evergreen runtime |
| User stuck on old version | `must_update` flag in manifest for security pushes |
| Platform fragmentation | matrix CI; emulator smoke tests |

## Cost
- Code-sign certs: $99/y mac, $300 EV win, $0 linux. NOT $0 — call this out as the only non-free element. Alternatives: free dev signing (less trusted, scary install warnings) for v0; flag as launch blocker.
- R2 hosting: 10 GB free. ~$0/mo at MVP scale.
- CI: GitHub Actions free 2000 min/mo.
