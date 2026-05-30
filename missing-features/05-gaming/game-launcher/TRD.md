# Game Launcher — TRD

## Architecture

```
+-----------------------+        +-----------------+        +------------------+
| Desktop client (Tauri)|        |  launcher-api   |        |     Postgres     |
|  +-----------------+  |        |  /v1/library    | <----> | linked_game_accts|
|  | scanner (Rust)  |  | -----> |  /v1/launch/log |        | + game_titles    |
|  +-----------------+  |        +-----------------+        +------------------+
|  | URI launcher    |  |               ^
|  +-----------------+  |               |
|  | running watcher |  |        +-----------------+
|  +-----------------+  |        |  Redis caches   |
+-----------------------+        +-----------------+
                                       ^
                                       |
+----------------+    realtime    +-----------+
| Mobile client  | <------------> |   WS hub  |   "@friend launched Apex" -> deep link
+----------------+                +-----------+
```

Scanner runs every 10 min on desktop and on focus; results posted to `launcher-api` only if changed (hash diff). Mobile never scans.

## REST routes

| Method | Path | Purpose | Auth |
|---|---|---|---|
| POST | /v1/launcher/library | Sync detected library (delta) | bearer + device |
| GET | /v1/users/:id/library | Public-visible library | bearer |
| POST | /v1/launcher/launch | Log launch + return URI | bearer |
| POST | /v1/launcher/heartbeat | Game-running ping | bearer |
| PATCH | /v1/launcher/preferences | Per-store/game visibility | bearer |
| GET | /v1/launcher/titles | Canonical title metadata | bearer |

## Manifest formats

**Steam (all OSes):**
- Root: `steamapps/libraryfolders.vdf` — list of library roots.
- Per game: `steamapps/appmanifest_{appid}.acf` — appid, name, install dir.
- Parser: VDF (text format, key/value); reuse `github.com/andygrunwald/vdf` patterns.

**Epic (Windows + macOS):**
- `%ProgramData%\Epic\EpicGamesLauncher\Data\Manifests\*.item` (Windows).
- `~/Library/Application Support/Epic/EpicGamesLauncher/Data/Manifests/*.item` (macOS).
- JSON files; key `CatalogItemId`, `DisplayName`, `LaunchExecutable`.

**GOG Galaxy:**
- SQLite `storage/galaxy-2.0.db`, table `InstalledBaseProducts`.
- Read-only open; close immediately.

## Launch URIs

| Store | URI |
|---|---|
| Steam | `steam://rungameid/{appid}` |
| Epic | `com.epicgames.launcher://apps/{namespace}%3A{itemId}%3A{appName}?action=launch&silent=true` |
| GOG | `goggalaxy://openGameView/{releaseKey}` |

Desktop app spawns the URI via `open` (macOS), `xdg-open` (Linux), `ShellExecute` (Windows). On URI failure, fall back to executable path.

## OAuth flows

None for v1 — manifest scan is OS-local. Library sync is authenticated by Flicko bearer token.

## Mobile fallback

Mobile receives the same `game_titles` row but the `launch` action becomes:
- iOS: `https://apps.apple.com/app/...` (best-effort match)
- Android: `market://details?id={pkg}` if known, else web Steam page
- Web: store page in new tab

## NFRs

- Scanner CPU: < 2% of one core during scan; < 0.1% idle.
- Scan duration: < 1s for 200 titles cold; < 200 ms warm (mtime cache).
- Library sync payload: gzip < 50 KB for 500 titles.
- Launch latency client side: < 200 ms from tap to URI dispatch.
- Heartbeat cadence: 30 s while game running, 0 when idle.

## Observability

- Metrics: `launcher_scans_total{store,result}`, `launcher_launches_total{store}`, `launcher_heartbeat_lag_seconds`, `launcher_match_rate` (titles matched / titles found).
- Logs: scanner emits structured per-store result JSON.
- Crash reporting: Sentry on scanner panics, scoped without paths (privacy).

## Failure modes

- Manifest file locked: skip + retry next cycle.
- VDF parse error: emit `launcher_parse_errors_total{store=steam}`, skip the file.
- URI not registered (user uninstalled launcher): toast + offer download link.
- Sync conflict (two desktops): merge by union of installed; remove only after both report uninstall.

## Title matching

`game_titles` is canonical (manually curated for top 500 + crowd-extended). Sync uses fuzzy match: store appid -> canonical id via `(store, store_appid)` unique index. Unmatched titles are stored with raw store name; back-end has weekly job to surface unmatched for ops review.

## Security

- Scanner is read-only; no exec, no write outside Flicko data dir.
- Library payload contains no executable paths (only canonical title id + install date).
- Privacy: user can mark library private (only friends), per-game hide, or fully off.
- Anti-cheat: no DLL injection, no overlay; all interaction is URI-based.
