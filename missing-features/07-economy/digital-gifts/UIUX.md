# UIUX - Digital Gifts

## Screen 1 - Gift Drawer (in stage / voice / chat)
```
+-----------------------------------------------+
|  Send a gift                            [x]   |
+-----------------------------------------------+
|  Balance: 12,400 coins (~$124)   [+ top up]   |
+-----------------------------------------------+
|  Categories  [Hot][Free][1-99][100+][Big]     |
+-----------------------------------------------+
|  +-------+ +-------+ +-------+ +-------+      |
|  | rose  | | clap  | | crown | | drone |      |
|  | 10    | | 50    | | 200   | | 1000  |      |
|  +-------+ +-------+ +-------+ +-------+      |
|  +-------+ +-------+ +-------+ +-------+      |
|  | fire  | | ufo   | | rocket| | castle|      |
|  | 1500  | | 2500  | | 5000  | | 9999  |      |
|  +-------+ +-------+ +-------+ +-------+      |
+-----------------------------------------------+
|  Combo  [ 1 ] [ 5 ] [ 10 ] [ 50 ] [ 99 ]      |
|        [Send 5 x rose - 50 coins]              |
+-----------------------------------------------+
```
Copy: low balance shows "Need 600 more coins" with inline top-up. Disabled gifts grayed.
Motion: tile press scales 0.95 then bounces. Combo selection emits subtle haptic light.
A11y: each gift has alt-text "Rose - 10 coins". Combo described as "send 5 roses, total 50 coins".

## Screen 2 - Top-up Sheet
```
+-----------------------------------------------+
|  Top up Flicko Coins                    [x]   |
+-----------------------------------------------+
|  +---+ +---+ +---+ +---+ +---+ +---+         |
|  |500| |1k | |5k | |10k| |25k| |custom|       |
|  |$5 | |$10| |$50| |$95| |$220| |       |     |
|  |   | |   | |+5%| |+10%| |+12%| |       |    |
|  +---+ +---+ +---+ +---+ +---+ +---+         |
+-----------------------------------------------+
|  Pay with                                     |
|   o Apple Pay                                 |
|   o Card **** 4242                            |
+-----------------------------------------------+
|        [Buy 5,000 coins for $50]              |
|  Coins are non-transferable, refundable in    |
|  full within 14 days if unspent.              |
+-----------------------------------------------+
```
Copy: bonus copy auto-shows "+10% bonus" pill on bigger packs. Custom opens slider 100-50000.
Motion: balance counter rolls up when topup succeeds, 700 ms ease-out.
A11y: bonus announced "ten percent bonus coins included". Pack buttons radio role.

## Screen 3 - Overlay (creator/stage view)
```
+-----------------------------------------------+
|                                               |
|         [stage feed]                          |
|                                               |
|   .---------------------------------.         |
|   | @santosh sent 5 roses    50 coin |        |
|   |  [animated rose burst]           |        |
|   '---------------------------------'         |
|                                               |
|   small toast bottom-left for combos          |
+-----------------------------------------------+
```
Copy: big-gift overlays show username, gift name, count, animation; small ones queue and merge into "+ 8 roses" toast if rapid.
Motion: rose burst lottie 1.6s; big gifts (>500 coins) take full screen 3s with parallax. Audio cue 200ms intro + 800ms decay.
A11y: overlay text persists in screen-reader-only live region; users can disable animation in settings (`reduce_motion=true` -> static badge for 3s instead).

## Screen 4 - Creator Gift Inbox + Leaderboard
```
+-----------------------------------------------+
| <- Gift inbox                                 |
+-----------------------------------------------+
|  Today  4,210 coins (~$42)                    |
|  This week 31,800 coins (~$318)               |
|  [Cash out >]                                 |
+-----------------------------------------------+
|  Top fans (last 7d)                           |
|  1. @meera     12,400 coins   [thank]         |
|  2. @ravi       7,200          [thank]        |
|  3. @ana        5,100          [thank]        |
+-----------------------------------------------+
|  Recent                                       |
|  @meera sent 100 fireworks 30s ago            |
|  @ravi sent 50 roses        1m ago            |
+-----------------------------------------------+
```
Copy: "Cash out" disabled if KYC incomplete with helper "Verify identity to cash out".
Motion: each new event slides in top with 220ms drop.
A11y: leaderboard table announces position+amount, "thank" button described.
