# Game Launcher — App Flow

## Sequence: scan + launch

```mermaid
sequenceDiagram
    participant User
    participant Desktop as Tauri client
    participant Scanner as scanner (Rust)
    participant API as launcher-api
    participant PG as Postgres
    participant OS

    Desktop->>Scanner: scan_all()
    Scanner->>OS: read libraryfolders.vdf
    OS-->>Scanner: paths
    Scanner->>OS: read appmanifest_*.acf
    OS-->>Scanner: titles
    Scanner-->>Desktop: [titles]
    Desktop->>API: POST /v1/launcher/library {delta}
    API->>PG: UPSERT linked_library
    API-->>Desktop: 200
    User->>Desktop: tap Launch on Valorant
    Desktop->>API: POST /v1/launcher/launch {title_id}
    API->>PG: INSERT launch_log
    API-->>Desktop: {uri: "steam://rungameid/123"}
    Desktop->>OS: open(uri)
    OS-->>Desktop: dispatched
    loop while running
        Desktop->>API: POST /v1/launcher/heartbeat {title_id}
    end
```

## Sequence: voice quick-launch fan-out

```mermaid
sequenceDiagram
    participant Voice as voice-svc
    participant Library as launcher-api
    participant Cache as Redis
    participant ClientA
    participant ClientB

    Voice->>Library: GET /v1/voice/:room/common-games
    Library->>Cache: GET common:{room}
    alt miss
        Library->>Library: intersect libraries of room members
        Library->>Cache: SET common:{room} ttl=30s
    end
    Library-->>Voice: [titles]
    Voice->>ClientA: WS push tray update
    Voice->>ClientB: WS push tray update
```

## State machine: per-title detection state

```
   +---------+    scan finds   +-----------+   user hides    +---------+
   | UNKNOWN| --------------->| INSTALLED  |---------------->| HIDDEN  |
   +---------+                 +-----------+                 +---------+
                                    |                              |
                                    | scan misses 3x (uninstalled) | unhide
                                    v                              v
                              +-------------+               +-----------+
                              | UNINSTALLED |               | INSTALLED |
                              +-------------+               +-----------+
                                    |                              |
                                    | re-scan finds                |
                                    +----------> INSTALLED <-------+
```

## State machine: launch attempt

```
  IDLE -> CONFIRMING -> DISPATCHED -> RUNNING -> ENDED
                  |          |           |
                  |          v           v
                  |       FAILED      CRASHED
                  v
              CANCELED
```

## Edge cases

1. **Multiple Steam libraries.** `libraryfolders.vdf` lists 4 paths; scanner walks each. Dedupe by `appid`.

2. **Game installed but Steam offline.** URI dispatch still works; Steam launches into offline mode. Heartbeat may report nothing if Steam isn't running; we treat absence as "ended".

3. **User installs game during voice session.** Next 10-min scan picks it up; quick-launch tray updates within 30 s of cache TTL.

4. **Two desktops same user.** Each posts a delta; backend merges by union; uninstall requires both desktops to drop within 24 h before we mark uninstalled.

5. **URI dispatch fails on Linux** (no `xdg-open`). Show error with copy-to-clipboard fallback `steam://...`.

6. **Custom Steam install path.** `libraryfolders.vdf` is canonical; we never assume default install path.

7. **Path with non-ASCII chars.** Rust scanner uses `OsString`; payload posts as base64 if non-UTF-8. Backend stores canonical id only, never the path.

8. **GOG sqlite locked by Galaxy.** Open with `mode=ro` and `immutable=1`; on lock, retry with 1s backoff x3, then skip.

9. **User toggles privacy to Off.** Backend deletes `linked_library` rows for that user; cache invalidated; quick-launch tray for friends updates within 30 s.

10. **Mobile receives launch event from desktop friend.** UI shows non-clickable "Arjun is playing Apex"; if user taps it, opens store deep link not launch.

11. **Game has multiple appids** (Apex, ARK with DLCs). `game_titles` flattens by base id; appid -> canonical via lookup table.

12. **Anti-cheat denies running with overlay tools.** Flicko has no overlay; no interaction. We document "If your anti-cheat blocks Flicko, please report" in Help.
