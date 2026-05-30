# Achievement System — UIUX

## Screens

### 1. Profile Shelf (visitor view)

```
+-----------------------------------------------+
|  @santosh  [Online]                  ...      |
|  Plays: Valorant, CS2, OW2                    |
|-----------------------------------------------|
|  Achievements                          See all|
|  +------+ +------+ +------+ +------+ +------+ |
|  |LEGEND| |EPIC  | |RARE  | |RARE  | |COMMN | |
|  |[icn] | |[icn] | |[icn] | |[icn] | |[icn] | |
|  |Voice | |Clip  | |Squad | |Year1 | |First | |
|  |1000h | |Star  | |Goals | |      | |Clip  | |
|  +------+ +------+ +------+ +------+ +------+ |
|  +------+                                     |
|  |EPIC  |   tap card -> detail sheet          |
|  |[icn] |                                     |
|  |Esprt |                                     |
|  |Fan   |                                     |
|  +------+                                     |
+-----------------------------------------------+
```

Copy:
- Empty state: "No achievements pinned yet — visit your shelf to choose six."
- "See all" pill counts unlocked: "See all (47)".

Motion: cards have a 1.5deg parallax tilt on scroll. Legendary cards pulse a 4s gold sheen.
A11y: each card exposes `Semantics(label: "Voice Warrior, Legendary, unlocked April 14 2026")`.

### 2. Achievement detail sheet

```
+-----------------------------------------------+
|         [ X ]                                 |
|                                               |
|         +-----------+                         |
|         |  ICON     |   <- 96x96, rarity ring |
|         +-----------+                         |
|                                               |
|         Voice Warrior                         |
|         LEGENDARY  -  0.4% of users           |
|                                               |
|         Spend 1,000 hours in voice channels   |
|         across all servers.                   |
|                                               |
|   Unlocked: April 14, 2026                    |
|   In server: The Lobby                        |
|                                               |
|   [  Pin to shelf  ]    [  Share clip  ]      |
+-----------------------------------------------+
```

### 3. Locked progress card

```
  +----------------------+
  | [icn-grey]           |
  | Globetrotter         |
  | Visit 50 servers     |
  | [=========         ] |
  | 32 / 50              |
  +----------------------+
```

Hidden achievements show `???` with a lock glyph until unlocked.

### 4. Unlock toast

```
   +---------------------------------+
   |  [icon]  Achievement unlocked!  |
   |          Voice Warrior          |
   |          Legendary              |
   +---------------------------------+
```

- Slides from top, 3s dwell, dismiss-on-tap opens detail sheet.
- Legendary triggers a 1.2s confetti burst (60 particles, reduced-motion: skip particles).
- Sound: short rising chime (Common), longer chord (Legendary). Respects system mute.

### Edit shelf screen

```
+-----------------------------------------------+
|  Edit shelf                       [ Save ]    |
|-----------------------------------------------|
|  Pinned (drag to reorder, max 6)              |
|  [1]  Voice Warrior         [-]               |
|  [2]  Clip Star             [-]               |
|  [3]  Squad Goals           [-]               |
|  [4]  Year One              [-]               |
|  [5]  First Clip            [-]               |
|  [6]  +  Pick one                             |
|-----------------------------------------------|
|  Available                                    |
|  []  Globetrotter                             |
|  []  Esports Fan                              |
|  ...                                          |
+-----------------------------------------------+
```

## Copy guidelines

- Achievement names: 1-3 words, evocative.
- Descriptions: imperative, under 60 chars.
- Rarity labels translated; rarity color is constant across locales.

## Motion

- Card hover (web): scale(1.04), 120ms ease-out.
- Pin action: card flies to slot, 300ms cubic-bezier(0.2, 0.9, 0.2, 1).
- Confetti palette: gold (#F4C430), white, deep purple (#5B2A86) for Legendary only.

## Accessibility

- All rarity is encoded by both color and icon shape (circle/square/hex/star) so colorblind users can distinguish.
- Reduced motion turns confetti into a 200ms scale fade; tilts disabled.
- Toasts are dismissible by pressing escape (web) or back button (Android).
- Screen readers announce unlocks once, deduplicated by id.

## Error states

- Shelf save fails: inline banner "Couldn't save shelf. Pulled back to last saved order. [Retry]".
- Detail sheet load fails: skeleton + retry button.
