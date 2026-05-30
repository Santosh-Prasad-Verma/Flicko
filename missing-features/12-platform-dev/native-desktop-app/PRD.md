# PRD: Native Desktop App

## Problem
Flicko's web app is great inside a browser tab but loses to dedicated competitors when users want a desktop-grade experience: persistent notifications across reboots, system tray controls, OS-level push, global hotkeys, and a fast cold start that does not require launching Chrome. The obvious path is Electron, but it carries a 200 MB bundle, slow startup, and a memory profile our heaviest power users have complained about. We want a native desktop app that feels first-class while keeping our Flutter web codebase as the source of truth for UI.

## Goals
- Ship a Tauri 2.x desktop app for macOS, Windows, and Linux that wraps the Flutter web build inside a Rust shell.
- Keep the bundle under 20 MB and cold-start under 2 seconds on a baseline machine.
- Provide an auto-updater that streams differential updates so users do not redownload the full bundle on every patch.
- Wire native push notifications through APNs on macOS and FCM/Windows Notification Service so messages arrive even when the app is closed.

## Non-Goals
- A native UI rewrite is out of scope; the Rust shell never renders Flicko UI itself.
- Mobile desktop bridges (Catalyst, ChromeOS) are not part of v1.
- Plugin sandboxing for user-installed extensions is reserved for a future product.

## Target Users
- Heavy daily users who keep Flicko open all day and want it pinned to the dock or taskbar.
- Community moderators who need persistent notifications even when the app is closed.
- Power users with global-hotkey workflows (push-to-talk, jump-to-server).

## Success Metrics
- Bundle size under 20 MB on every platform.
- Median cold start under 2 seconds on a 2020-era laptop with 8 GB RAM.
- 30 percent of monthly active web users adopt the desktop app within 90 days of GA.
- Auto-update success rate above 99 percent; failed updates self-heal on next launch.
- Crash-free sessions above 99.5 percent.

## User Stories
1. As a moderator, I close the app to a tray icon, get a native toast for a flagged message, and click to jump straight into the moderation panel.
2. As a power user, I press a global hotkey to mute my mic without alt-tabbing away from my game.
3. As a new desktop user, my app updates itself in the background overnight and a small "What's new" pill appears the next time I launch.
4. As a privacy-conscious user, I see exactly what telemetry the app sends and toggle it off in Preferences.

## Functional Requirements
- Single binary per platform; signed and notarized on macOS, EV-signed on Windows, AppImage and deb/rpm on Linux.
- System tray icon with quick actions: open, mute mic, set status, quit.
- Global hotkeys configurable in Preferences: push-to-talk, mute, deafen, jump-to-search.
- Native push: app subscribes for the signed-in user, server pushes via APNs/FCM with end-to-end-style payload encryption (the body is encrypted client-side; only metadata is in the cloud channel).
- Auto-updater: differential patches via bsdiff; full fallback if the patch fails.
- Window state persistence: remembers position, size, maximized, multi-monitor placement.
- Deep links: `flicko://server/123/channel/456` opens the app and navigates.

## Constraints
- Reuse the Flutter web build verbatim; the desktop app must not fork the UI codebase.
- Tauri 2.x is the only supported shell. No Electron, no CEF.
- Telemetry is opt-in; default off for EU users, default on with disclosure elsewhere.
- Update channel selection: stable, beta, dev. Stable rollout is staged.

## Risks
- Webview parity gap: WebKit on macOS, WebView2 on Windows, WebKitGTK on Linux. Mitigation: a feature-detection layer that disables features the host webview cannot support.
- Tauri 2.x maturity. Mitigation: pin to a known-good release and track upstream issues.
- Push payload privacy. Mitigation: payload encryption with a per-device key stored in OS keychain.

## Open Questions
- Linux distribution preference: Flatpak first or AppImage? Leaning AppImage for breadth, Flatpak as a fast-follow.
- Should we expose a small Rust plugin API for trusted partners (e.g., overlay integrations)? Probably v1.1.

## Release Plan
- Internal alpha for staff with daily auto-updates against the dev channel.
- Closed beta with 500 invited power users on the beta channel.
- Public GA on stable channel with phased rollout (10 percent, 50 percent, 100 percent over two weeks).
