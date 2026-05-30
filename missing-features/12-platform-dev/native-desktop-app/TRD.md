# TRD: Native Desktop App

## Architecture
The desktop app is a Tauri 2.x application. The Rust shell owns the application lifecycle, system integration (tray, hotkeys, push, updater), and a small command surface exposed to the embedded webview. The webview hosts the existing Flutter web build, served from disk by Tauri's asset protocol with no network round-trip. Communication between Rust and Flutter goes through Tauri's invoke bridge, wrapped in a typed Dart channel.

## Components
- `desktop/src-tauri/` Rust crate.
  - `main.rs` bootstrap, window creation, tray, lifecycle.
  - `updater/` differential update client.
  - `push/` APNs (macOS), WNS (Windows), FCM (Linux via xdg) integration.
  - `hotkeys/` global hotkey registration.
  - `telemetry/` opt-in metrics emitter.
  - `keychain/` OS keychain wrapper for tokens and per-device keys.
  - `commands/` invoke handlers exposed to the webview.
- `desktop/web-bridge/` Dart package: typed wrappers over Tauri invoke. Drops in as a dev dependency in the Flutter build.
- `desktop/build/` build scripts for each platform, code signing, notarization.

## Asset Loading
Tauri 2.x asset protocol serves the Flutter web build from a frozen directory. The build pipeline produces a hashed manifest; Rust verifies the manifest at startup before serving. Any tamper triggers a hard refresh from the update server.

## Update Pipeline
Releases are produced by GitHub Actions across the three platforms. Each build emits a full tarball plus a bsdiff patch against the previous release on the same channel. Manifests are signed with an Ed25519 key kept in a hardware token; the public key is baked into the shell.

The updater runs on a 4-hour cadence and at every cold start. It fetches the channel manifest, picks the smallest path (patch if available and applicable, else full), downloads, verifies signature, applies in a staging directory, atomic-renames, and prompts the user to restart if interactive or applies on next launch otherwise.

A failed patch falls back to a full download. A failed full download retries with exponential backoff. After three full failures, the user sees a banner and the in-app retry button.

## Push Notifications
On macOS, the app registers with APNs via `UNUserNotificationCenter` through a small Swift helper compiled into the binary. The device token is sent to Flicko's push gateway, which proxies to APNs.

On Windows, the app uses the Windows Push Notification Service (WNS) and the modern `ToastNotificationManager` API. Tokens are managed similarly.

On Linux, native push is best-effort: we use a long-poll fallback to the Flicko realtime service since neither GNOME nor KDE has a unified push channel. The local desktop notification surface uses `notify-send` via `org.freedesktop.Notifications`.

Payloads are encrypted client-side. The desktop app generates a per-device X25519 keypair on first launch, stores the private key in the OS keychain, and registers the public key with the server. Push payloads include only the encrypted blob plus a minimal "you have a notification" hint; the actual content is decrypted in-process.

## Global Hotkeys
The Rust shell registers system-level hotkeys via `tauri-plugin-global-shortcut`. The webview can register, unregister, and update bindings via invoke. Conflicts (a binding already registered by another app) surface as an error and the UI prompts to pick a different combination.

## System Tray
The tray icon shows app status (online, idle, dnd) via swappable assets. The menu surfaces Open Flicko, Mute Mic, Set Status, Quit. Click-to-open is platform native: single click on Windows and Linux, double click on macOS.

## Window State
Position, size, maximized, and which monitor are persisted to a small SQLite file in the app data directory. On launch, the shell validates the saved monitor still exists; if not, it falls back to the primary.

## Deep Links
Each platform registers `flicko://` as a URL scheme. The shell routes incoming URLs to the webview via an invoke event, which is consumed by the existing Flutter router.

## Telemetry
Opt-in telemetry sends crash reports (via `sentry-rust`) and minimal usage signals (cold start time, update outcome, push delivery success). Payloads are scrubbed of all identifiers before send. The privacy panel in Preferences toggles this and shows a sample of what was last sent.

## Backend Integration
Migration 248 introduces `desktop_releases`, `desktop_telemetry`, and supporting tables. A new HTTP surface at `/api/v1/desktop/...` handles release manifests, push token registration, and telemetry ingestion. Release manifest endpoint is publicly cacheable; the rest require auth.

## Security
- All native-side IPC uses Tauri's permission model; only allowlisted invoke commands are exposed.
- Updater signature verification is mandatory; unsigned manifests are rejected.
- Per-device keys never leave the keychain; export is impossible by design.
- The webview has CSP headers locked down to `tauri://` and the app's API origin.
- macOS hardened runtime enabled, Windows builds EV-signed, Linux builds reproducible.

## Performance Targets
- Cold start: under 2 seconds median on a 2020 MBA / equivalent Windows / equivalent Linux.
- Idle memory: under 200 MB resident.
- Bundle: under 20 MB across platforms.
- Auto-update apply: under 5 seconds for differential patches under 5 MB.

## Failure Modes
- Webview crash: Rust shell detects via the IPC heartbeat and offers to relaunch; restart preserves window state.
- Push token expiration: gateway returns expired, app refreshes token on next launch.
- Update server unreachable: app continues to run on the current version, retries silently.
- Keychain access denied: the user is prompted with a one-time dialog explaining why and what is stored.
