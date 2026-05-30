# Game Launcher — UIUX

## Screens

### 1. Voice channel — Quick Launch tray (desktop)

```
+------------------------------------------------------+
|  # general-voice          [4 in voice]               |
|------------------------------------------------------|
|  [santosh]  [meera]  [arjun]  [+1 more]              |
|                                                      |
|  Quick launch -- common games                        |
|  +-----------+ +-----------+ +-----------+           |
|  | [VAL]     | | [CS2]     | | [APEX]    |           |
|  | Valorant  | | CS2       | | Apex      |           |
|  | 4 ready   | | 3 ready   | | 2 ready   |           |
|  | [Launch ] | | [Launch ] | | [Launch ] |           |
|  +-----------+ +-----------+ +-----------+           |
|                                                      |
|  +-----------+                                       |
|  | All games >                                       |
|  +-----------+                                       |
+------------------------------------------------------+
```

Copy:
- "X ready" = installed by X members in this voice room.
- Tap card opens detail with "Launch", "Invite", "Hide".
- Mobile shows the same tray but the button is "Get on Steam" / "Open in store".

Motion: card slides up 8 px on hover; on launch, the icon morphs into a pulsing "Launching..." for 2 s, then "In game".
A11y: announce "Valorant — installed by 4 members in this voice room. Double-tap to launch."

### 2. Library screen

```
+------------------------------------------------------+
|  My library                          [ Sync now ]    |
|------------------------------------------------------|
|  Steam (147)  Epic (12)  GOG (3)                     |
|------------------------------------------------------|
|  [VAL]  Valorant                            [Hide]   |
|  [CS2]  Counter-Strike 2                    [Hide]   |
|  [APEX] Apex Legends                        [Hide]   |
|  [HK]   Hollow Knight                       [Hide]   |
|  ...                                                  |
|------------------------------------------------------|
|  Privacy                                             |
|  Share library:  [ Friends only  v ]                 |
|  [ ] Hide playtime                                   |
+------------------------------------------------------+
```

Empty state: "No games detected. Install Steam, Epic, or GOG to populate. [Help]".

### 3. Launch confirmation modal (first time per game)

```
        +------------------------------------+
        |  Launch Valorant?                  |
        |                                    |
        |  Flicko will open Steam and start  |
        |  the game.                         |
        |                                    |
        |  [ ] Don't ask me again            |
        |                                    |
        |  [ Cancel ]    [ Launch ]          |
        +------------------------------------+
```

### 4. Mobile fallback card

```
+--------------------------------------------+
|  [VAL]  Valorant                           |
|         Your friends are playing.          |
|                                            |
|  [  Open in store  ]                       |
|                                            |
|  Install on desktop to launch from here.   |
+--------------------------------------------+
```

## Copy

- Privacy default copy: "Only friends can see your library. Servers and strangers see nothing."
- Permission prompt: "Flicko wants to read your installed games. Read-only. You can revoke any time in Settings."
- Error: "We couldn't reach Steam. Make sure it's installed. [Try again]".

## Motion

- Quick-launch cards animate in stagger (40 ms each).
- "Launching..." button uses 600ms breathing pulse.
- Library list virtualized; scroll uses overscroll bounce on iOS only.

## Accessibility

- All cards are buttons with explicit roles.
- Launch confirmation requires explicit tap; never auto-launch.
- Reduced motion disables card slide and pulse; uses opacity fades.
- High-contrast mode: card border thickness 2 -> 3, rarity colors swap to AA-compliant set.

## Privacy surface

- Settings -> Privacy -> Game library has three-tier: Public / Friends / Off.
- Per-game hide is sticky across re-syncs.
- "Off" disables sync entirely; library is wiped server-side within 24 h.

## Error states

- Scanner unavailable (e.g. Steam not installed): surfaces a passive note in the library tab; no popup.
- URI handler missing: modal with one-tap "Install Steam" link.
- Sync conflict: silent merge; never user-visible.
