# Game Launcher — PRD

**Summary:** Desktop client scans Steam/Epic/GOG manifests for installed games and offers one-click launch from Flicko; mobile redirects to platform store pages, turning the app into a hub between conversation and play.

## Problem

When a user is in voice chat planning a session, they alt-tab to find a launcher, then to the game. This dropout is friction; users disengage from voice during the gap. Discord's Game Activity is detection-only — it does not start games. Flicko can short-circuit this with a launcher built on free, local OS APIs.

The launcher must:
- Detect installed games via official manifest formats (no scraping).
- Launch via documented URI handlers (`steam://run/{appid}`, `com.epicgames.launcher://...`).
- Refresh in the background; surface "Ready to play" cards in voice channels.
- Degrade gracefully on mobile to "Open store" deep links.

## JTBDs

1. As a player coordinating a session, when my crew picks Valorant, I want to launch it without leaving Flicko so I stay in voice.
2. As a curator of my library, I want my installed games discovered automatically so I do not maintain a list.
3. As a friend joining a voice channel, I want to see what everyone has installed so we pick something fast.
4. As a mobile user, when a desktop friend launches Apex, I want a one-tap "Get Apex" link to my platform's store.
5. As a privacy-conscious user, I want to opt out of library sharing without losing launch ability.

## Scope

**In scope:**
- Desktop app (Windows/macOS/Linux): scan Steam (`libraryfolders.vdf`, `appmanifest_*.acf`), Epic (`Manifests/*.item`), GOG Galaxy (sqlite at `%ProgramData%\GOG.com\Galaxy\storage\galaxy-2.0.db`).
- One-click launch via OS URI handlers.
- Voice-channel "Quick launch" tray of common games among connected members.
- Mobile fallback: open platform store (Steam mobile site, Epic web, GOG web).
- Privacy: per-store toggle to share library; per-game hide.

**Out:**
- Battle.net (no public manifest format; deferred).
- Riot client direct launch (covered in stats integration).
- Cloud saves / play history.
- DRM-free local launches outside the 3 stores.

## Metrics

| Metric | Target | Measure |
|---|---|---|
| Voice session launch rate | >= 35% of voice sessions trigger >= 1 launch | server logs |
| Launch -> game-running detection | >= 90% within 60s | desktop heartbeat |
| Time saved per launch | >= 4 sec median vs control | timing instrumentation |
| Library discovery completeness | >= 95% of installed games detected | self-reported survey + diff |

## Competitive table

| App | Auto-discover | Launch | Multi-store | Voice integration | Cost |
|---|---|---|---|---|---|
| Discord | Detect-only | No | n/a | Activity badges | Free |
| Steam Friends | Steam only | Yes | No | Limited | Free |
| Overwolf | Yes | Partial | Yes | Add-on | Freemium |
| Razer Cortex | Yes | Yes | Yes | No | Free |
| **Flicko** | Yes | Yes | Steam/Epic/GOG | Native voice | $0 |

## Risks

- **Manifest format drift.** Mitigation: pin to documented locations; integration tests against fixture files; degrade silently on parse failure.
- **OS sandbox restrictions** (macOS gatekeeper, sandboxed Steam on Linux Flatpak). Mitigation: explicit support matrix; show "Not detectable in this install mode" hint.
- **Anti-cheat false flags** when Flicko reads paths. Mitigation: read-only, no injection, never touches game memory.

## Open questions

- Should we display playtime estimates on cards? Steam exposes some via local config; risky for trust. Defer.
- Prompt the user for first scan, or auto on install? Lean: prompt on first launch with explicit consent.
