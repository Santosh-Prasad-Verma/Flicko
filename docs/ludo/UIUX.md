# Ludo - UI/UX Design Spec

**Last updated:** 2026-05-29

## 1. Design language

The Ludo feature lives inside Flicko's "premium dark gaming" theme. It uses the same maroon/gold/purple stack as the gaming hub so navigating in feels continuous, but the **board itself** stays the classic high-contrast white-and-coloured layout because that's what players expect from Ludo.

### 1.1 Color tokens

| Token | Hex | Usage |
|---|---|---|
| `bg.deep` | `#1A0A0A` | Lobby/leaderboard backgrounds |
| `bg.mid` | `#2D0E0E` | Sheet backgrounds, cards |
| `accent.red` | `#C0392B` | Primary CTA, active state |
| `accent.gold` | `#F0C040` | Highlights, selection rings |
| `accent.purple` | `#8B5CF6` | Secondary CTA, gradients |
| `accent.teal` | `#1E5162` | Board frame background |
| `player.red` | `#D5151D` | Player 1 token + pocket |
| `player.green` | `#00A049` | Player 2 token + pocket |
| `player.yellow`| `#FFDE17` | Player 3 token + pocket |
| `player.blue` | `#28AEFF` | Player 4 token + pocket |
| `text.primary`| `#FFFFFF` | Headlines |
| `text.muted` | `rgba(255,255,255,0.6)` | Subtitles |

### 1.2 Typography

- **Display / titles:** `Orbitron` 900, letter-spacing +1.4
- **Body:** `Inter` 400-600
- **Numerics (scores, ELO):** `Space Mono` 700

### 1.3 Motion guidelines

| Element | Duration | Curve |
|---|---|---|
| Mode-card tap → push | 250 ms | `Curves.easeOutCubic` |
| Dice tumble | 800 ms | Lottie composition |
| Token per-cell hop | 200 ms | `Curves.linear` (matches RN port) |
| Capture rewind | 40 ms / cell | linear |
| Win modal entry | 400 ms | `Curves.easeOutBack` |
| Fireworks Lottie | 4000 ms | one-shot, IgnorePointer |

## 2. Screens

### 2.1 LudoHomeScreen

```
+--------------------------------------------------+
| [<]                                    [trophy]  |
|                                                  |
|              ┌────────────┐                      |
|              │   LOGO     │                      |
|              └────────────┘                      |
|                                                  |
| CHOOSE YOUR                                      |
| GAME MODE                                        |
|                                                  |
| ╔════════════════════════════════════╗  red→prp  |
| ║ [ctrl] PLAY ONLINE              [>]║           |
| ║        random opponents · ranked   ║           |
| ╚════════════════════════════════════╝           |
| ╔════════════════════════════════════╗  prp→teal |
| ║ [bot]  VS COMPUTER              [>]║           |
| ║        pick 1-3 bots                ║           |
| ╚════════════════════════════════════╝           |
| ╔════════════════════════════════════╗  teal→grn |
| ║ [grp]  PASS & PLAY              [>]║           |
| ║        2-4 players, one device     ║           |
| ╚════════════════════════════════════╝           |
| ╔════════════════════════════════════╗  gold→red |
| ║ [link] INVITE FRIENDS           [>]║           |
| ║        private match link          ║           |
| ╚════════════════════════════════════╝           |
+--------------------------------------------------+
```

- 280×280 ambient red glow top-right, 220×220 purple glow bottom-left.
- Logo PNG, falls back to a 4-quadrant gradient circle if asset missing.
- Each mode card: 16dp radius, drop shadow with the gradient's first colour at 30% alpha, 16 blur.

### 2.2 LudoBoardScreen

```
+--------------------------------------------------+
| [≡]                                  [P1 P2 P3 P4]|
|                                                  |
|     [pile][dice][>]              [<][dice][pile] |  P2/P3 dice row
|                                                  |
|     ┌───────────────────────────┐                |
|     │  G-pocket │ vp │ Y-pocket │                |
|     │  ─────────┼────┼───────── │                |
|     │  hp       │ ◢◣ │       hp │                |
|     │           │ ◣◢ │          │                |
|     │  ─────────┼────┼───────── │                |
|     │  R-pocket │ vp │ B-pocket │                |
|     └───────────────────────────┘                |
|                                                  |
|     [pile][dice][>]              [<][dice][pile] |  P1/P4 dice row
+--------------------------------------------------+
```

- Background `accent.teal #1E5162` per the original RN port.
- Board frame: `white`, 6 dp padding, 10 dp radius, drop shadow (black 40%, 16 blur).
- Pocket coloured square with a 70%×70% white inner frame holding 4 circular slots.
- Active player's dice shows the pile pictogram + clickable die + pulsing arrow at +/-5 dp.
- ScoreBadge top-right shows `0/4 .. 4/4` per player; current player's dot has a white ring.
- 2.5 s blink-fade `START!` overlay on entry (fades through Curves.linear).

### 2.3 LudoMatchmakingScreen

- Centred 220×220 diceroll Lottie.
- Title `Finding players…`, subtitle live counter `<n> seconds`.
- CANCEL text-button below.

### 2.4 LudoLeaderboardScreen

- Each row 60 dp, 14 dp radius, white 5% bg, ring colour matches medal tier (gold/silver/bronze for top 3).
- Right-side ELO chip: red→purple gradient pill, Space Mono numeric.

### 2.5 WinnerModal & MenuModal

- Both share a navy gradient (`#0F0C29 → #302B63 → #24243E`), gold 2 dp border, 20 dp radius.
- WinnerModal stacks: medal circle, "Player N Wins!", trophy Lottie, NEW GAME button, EXIT button. Fireworks Lottie overlays the entire stack via `IgnorePointer`.
- MenuModal stacks 3 buttons: RESUME / NEW GAME / EXIT.

## 3. Iconography & assets

- Star spots: `Icons.star_border_rounded` 14 dp grey.
- Arrow spots: `Icons.east` 12 dp grey, rotated by cell id (12=0°, 25=90°, 38=180°, else -90°).
- Pile tokens: PNG from `assets/ludo/images/piles/{red|green|yellow|blue}.png`, fallback = filled circle with white border.
- Dice faces: PNG `assets/ludo/images/dice/{1..6}.png`, fallback = digit text.

## 4. Accessibility

| Concern | Status |
|---|---|
| Dice tap-target | 50×50 px (above 48 px guideline) ✓ |
| Token tap-target on board | ~22 px (with hidden 22 px touch padding) - **borderline**, plan to wrap in 44×44 invisible hit area |
| Colour-only meaning | Each player carries an emoji + label on dice strip + scoreboard - safe ✓ |
| Reduced motion | Not yet wired - **TODO**: respect `MediaQuery.disableAnimations` to skip Lottie loops and shorten the per-cell delay |
| Screen reader | Tokens are unlabeled - **TODO**: add `Semantics(label: 'Red token 1, on cell 14')` |
| Mute toggle | `LudoSoundService.setMuted` exists but no UI - **TODO** in MenuModal |

## 5. Empty/error states

| Screen | Trigger | Treatment |
|---|---|---|
| Lobby | Audio asset missing | Silent, log only |
| Board | Pile PNG missing | Coloured circle with white border |
| Board | Lottie missing | Static fallback (CircularProgressIndicator for dice, gradient avatar for matchmaking) |
| Leaderboard | API down | Mock 5-row list (NayanX, KingDice, Valkyrie, StarLord, Aurora) - no banner |
| Leaderboard | API error visible | Card with retry button |

## 6. Open design questions

- **Pause behaviour:** does the menu pause the bot's turn? (Currently no; pause is a TODO.)
- **Spectate flow:** when a friend joins after the game starts, should they spectate or queue for the next match?
- **Leaderboard segmentation:** global only vs friends-only vs server-only? (v1 is global only.)
- **Win celebration length:** 4 s fireworks too long? Telemetry needed.
