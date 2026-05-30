# Game Launcher — Implementation Plan

## Phases

### Phase 1 — Title catalog + canonical IDs (week 1)

Backend (`backend/internal/services/gaming/launcher/`):
- [ ] `migrations/151_create_launcher.sql`.
- [ ] `models/title.go`, `models/library.go`.
- [ ] `repo/postgres.go` — `UpsertLibrary`, `DeleteLibrary`, `IntersectVoiceRoom`, `MatchTitle`.
- [ ] `seeds/titles.json` — top 500 titles with store ids.
- [ ] `seeds/import_cmd/main.go` — one-time importer.
- [ ] `handlers/titles.go` — GET `/v1/launcher/titles` paginated.

### Phase 2 — Desktop scanner (week 2-3)

Desktop (`desktop/src-tauri/scanner/`):
- [ ] `steam.rs` — parse VDF + ACF.
- [ ] `epic.rs` — parse JSON manifests.
- [ ] `gog.rs` — open SQLite read-only.
- [ ] `cache.rs` — mtime-based skip-unchanged.
- [ ] `scheduler.rs` — 10-min tick + on-focus.
- [ ] `match.rs` — call backend match API; cache locally.
- [ ] `bridge.rs` — IPC to Tauri front-end and Flicko web bundle.

Front-end (`desktop/src/launcher/`):
- [ ] `LibraryView.tsx`, `QuickLaunchTray.tsx`.
- [ ] `useLibrary.ts` — query + mutate.
- [ ] First-run consent dialog.

### Phase 3 — Launch + heartbeat (week 4)

Backend:
- [ ] `handlers/launch.go` — POST returns URI template populated for that user's store appid.
- [ ] `handlers/heartbeat.go` — POST updates `launch_log.status='running'`, sets `ended_at` after 90s of silence (sweeper).
- [ ] `cmd/launch-sweeper/main.go` — 30s loop closing stale runs.

Desktop:
- [ ] `launch.rs` — dispatch URI per OS; fallback to executable.
- [ ] `running.rs` — poll `tasklist` (Windows), `pgrep` (mac/linux) by exe basename to detect running.
- [ ] Heartbeat coroutine with 30s cadence.

### Phase 4 — Mobile fallback + voice tray (week 5)

Backend:
- [ ] `handlers/voice_common.go` — `GET /v1/voice/:room/common-games`.
- [ ] WS push when membership of voice room changes -> recompute + broadcast.

Mobile (`mobile/lib/features/gaming/launcher/`):
- [ ] `data/api/launcher_api.dart`.
- [ ] `presentation/widgets/quick_launch_tray.dart` — horizontal scroll.
- [ ] `presentation/widgets/store_open_button.dart` — platform-specific deep links.
- [ ] `presentation/screens/library_view_screen.dart` — read-only view of own library on mobile.

### Phase 5 — Privacy + polish (week 6)

Backend:
- [ ] `handlers/preferences.go` — PATCH visibility/hide_playtime.
- [ ] Tombstone job: when visibility=off, hard delete library rows after 24h.
- [ ] Audit log row in `launch_log` with status='off-toggled'.

Mobile/Desktop:
- [ ] Settings -> Privacy -> Game library section.
- [ ] Per-game "Hide" action on long-press.

## Test plan

| Test | Tool |
|---|---|
| VDF parser fixture (5 sample libraries) | Rust unit |
| Epic manifest fixture | Rust unit |
| GOG sqlite fixture | Rust unit + integration |
| Title match accuracy >= 95% | match-cli with seeded set |
| `POST /library` delta correctness | Go integration |
| `intersect_voice_room` < 50 ms p95 | bench |
| URI dispatch on each OS | manual + CI smoke |
| RLS: friend can read, stranger cannot | dredd |
| Privacy off wipes within 24 h | scheduled test |

## Rollout

1. Ship desktop scanner behind `feature.launcher_scanner=false`.
2. Internal dogfood 1 week; verify match rate >= 95% across staff libraries.
3. 5% rollout, monitor `launcher_match_rate` and parse error metrics.
4. 25% -> 100% over 2 weeks.
5. Mobile fallback ships in same release; quick-launch tray gates separately.

## $0 cost

- Manifest reads are local; no API calls to Valve/Epic/GOG.
- `launch_log` is high-volume; schedule monthly partition + 90-day retention to keep within free Postgres tier.
- Title catalog is small (< 5 MB) and CDN-cached.
- Heartbeats are 30s; ~120/hr per game; estimated 50k QPS at 1M MAU peak. Mitigate with batch endpoint and Redis shedding.
