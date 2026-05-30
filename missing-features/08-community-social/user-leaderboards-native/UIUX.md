# User Leaderboards Native — UI/UX Design

## 1. Design Principles

- Numbers must feel earned, not gamified to addictive levels
- Self-card is always visible regardless of rank
- Avoid streak-pressure language
- Owner controls clearly visible and reversible

## 2. Information Architecture

- Entry points: Server -> Members -> Leaderboard, profile XP chip, server settings -> XP
- Parent: members area
- Deep link: `flicko://server/<id>/leaderboard`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Leaderboard | Top N + self | empty, loading, content, error |
| 2 | Self detail | Sources breakdown | content |
| 3 | Settings -> XP | Rules + reset | content |
| 4 | Level up celebration | Toast + sheet | one |
| 5 | Badges grid | All earned badges | content, empty |

## 4. Wireframes (ASCII)

### Leaderboard screen

```
+--------------------------------------------------+
| <  Aurora Devs - Leaderboard         filter (V)  |
+--------------------------------------------------+
|  Window:  [Today  *7d*  30d  All]                |
+--------------------------------------------------+
|                                                  |
|  +-- ME ----------------------------+            |
|  | #18  @sarah  L14  1,842 xp       |   v3       |
|  | XP to L15: 158 / 500             |            |
|  +----------------------------------+            |
|                                                  |
|  Rank  User           Level   XP    delta        |
|   1    @riku   L26   8,402     0                 |
|   2    @lex    L24   7,011    +1                 |
|   3    @nova   L22   6,544    -1                 |
|   4    @kai    L20   5,201     0                 |
|   ...                                             |
|  18    @sarah  L14   1,842    +3                 |
+--------------------------------------------------+
```

### Self detail

```
+--------------------------------------------------+
| <  Your XP                                       |
+--------------------------------------------------+
|  Level 14                                        |
|  ##############___________  1842 / 2000          |
|                                                  |
|  Sources (last 30 days)                          |
|   Messages          1,200                         |
|   Voice minutes       380                         |
|   Reactions received  140                         |
|   Helpful votes        80                         |
|   Daily logins         42                         |
|                                                  |
|  Cooldowns                                       |
|   per-minute cap: 60 xp/min                      |
|                                                  |
|  Badges                                          |
|   [L5]  [L10]  [L25 (locked)]                    |
+--------------------------------------------------+
```

### Settings -> XP

```
+--------------------------------------------------+
| <  XP rules                                      |
+--------------------------------------------------+
|  Enable leaderboard         [ on  /  off ]       |
|                                                  |
|  Weights                                         |
|   Message              [ 5 ]                     |
|   Voice minute         [ 2 ]                     |
|   Reaction received    [ 1 ]                     |
|   Helpful vote         [ 8 ]                     |
|   Event attend         [25 ]                     |
|   Daily login          [ 5 ]                     |
|                                                  |
|  Per-minute cap        [60 ]                     |
|  Decay per day         [ 0 ]                     |
|                                                  |
|  Excluded channels     [ select... ]             |
|                                                  |
|  Season started Mar 1  [ Reset season ]          |
+--------------------------------------------------+
```

### Level up sheet

```
+--------------------------------------------------+
|        You hit Level 15                          |
+--------------------------------------------------+
|     [confetti minimal]                           |
|     +200 xp earned this hour                     |
|     [ Share to feed ]   [ Got it ]               |
+--------------------------------------------------+
```

## 5. Component Specs

### `LeaderboardRow`
- Props: rank, user, level, xp, deltaRank
- Pinned self-card at top of list

### `XpProgressBar`
- Single line progress bar with `xp_to_next` tooltip

## 6. Empty / Error / Loading

- **Empty:** "No XP earned yet. Send a message or join voice."
- **Error:** banner with retry
- **Loading:** 5 skeleton rows

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Leaderboard |
| Self card delta | -3 spots since yesterday |
| Empty | No XP earned yet. |
| Cooldown | XP cooling down for fairness |
| Reset confirm | Reset season? Seasonal XP zeros, all-time stays. |
| Bot exclusion note | Bot accounts are not counted. |

## 8. Motion

- Rank delta arrow appears 220ms after row mount
- Level up: confetti emitter, kept short, 1.4s
- Reduced motion: replace confetti with static check

## 9. Accessibility

- Rows announce "rank, name, level, xp, delta"
- Self-card prominently labeled
- Progress bar exposes percent and remaining xp via aria-valuenow

## 10. Responsive

- Phone: single column
- Tablet/web: two-column with self panel persistent

## 11. Theming

- Self card uses tinted `primaryContainer`
- Level chip uses server accent
