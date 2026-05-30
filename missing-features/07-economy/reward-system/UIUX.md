# UIUX - Reward System

## Screen 1 - Reward Toast (member)
```
                                +----------------+
                                |  +1 reward     |
                                |  100 coins     |
                                |  Daily streak  |
                                |  [view]        |
                                +----------------+
```
Copy: short title + reward count. Tap opens detail screen.
Motion: slide in top-right, dwell 4 s, swipe-to-dismiss; 200 ms ease.
A11y: announces "You earned 100 coins for daily streak". Persistent in notification center.

## Screen 2 - Reward History
```
+-----------------------------------------------+
| <- My rewards                                 |
+-----------------------------------------------+
|  This month  3,200 coins + 4 badges           |
+-----------------------------------------------+
|  Today                                        |
|  +-------------------------------------------+|
|  | * Daily streak day 7    +200 coins        ||
|  | * First chat reply      +50 coins         ||
|  +-------------------------------------------+|
|  Yesterday                                    |
|  +-------------------------------------------+|
|  | * Stage host 30min      +500 coins        ||
|  | * Badge: Mic Up         (cosmetic)        ||
|  +-------------------------------------------+|
+-----------------------------------------------+
```
Copy: empty state "No rewards yet. Try sending your first message".
Motion: cards pop in 80 ms stagger.
A11y: each row reads kind + value + reason.

## Screen 3 - Admin Rule Editor
```
+-----------------------------------------------+
| <- Edit rule: Daily streak                    |
+-----------------------------------------------+
|  Trigger event   [user.daily_login    v]      |
|  Predicate       streak_days >= 7             |
|                  [+ add condition]            |
|  Reward          [coins v] [200]              |
|  Cooldown        [24 h v]                     |
|  Daily budget    [$ 500 ] = 50,000 coins       |
|  A/B variant     [holdout 10% off]             |
|  Active          [ x ]                         |
+-----------------------------------------------+
|  [Dry run last 24h] -> 184 grants, $36.80      |
|  [Save draft]    [Promote to active]           |
+-----------------------------------------------+
```
Copy: dry-run shows projected cost; promote requires confirm with budget acknowledgment.
Motion: predicate row collapses/expands smoothly 200 ms.
A11y: form fields labeled, all numeric inputs filtered, screen reader states budget projection.

## Screen 4 - Milestone Celebration
```
+-----------------------------------------------+
|        +----------------------------+          |
|        |   confetti + lottie crown  |          |
|        |                             |         |
|        |   100 subscribers!          |         |
|        |   $10 bonus + Gold badge    |         |
|        |                             |         |
|        |        [Awesome]            |         |
|        +----------------------------+          |
+-----------------------------------------------+
```
Copy: dynamic with milestone count. Bonus copy hidden if no cash.
Motion: confetti 1.6 s, badge shimmer, haptic heavy on entry.
A11y: animation muted with reduce_motion; screen reader: "Congratulations on 100 subscribers, you earned 10 dollars and the Gold badge."
