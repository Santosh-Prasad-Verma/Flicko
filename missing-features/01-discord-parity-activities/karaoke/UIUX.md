# Karaoke Night — UI/UX

## Design Principles
- Lyrics are the show; everything else gets out of the way.
- The mic is sacred — clear visual cue when active.
- Score reveal should feel earned, not punitive.
- Stealth mode for nervous singers; competition for the bold.

## Screen 1 — Activity Picker entry

```
+--------------------------------------------------+
|  < Back     Start an Activity                    |
+--------------------------------------------------+
|                                                  |
|  [ ] Karaoke Night          [Start]              |
|      Sing along, get scored, no judgement        |
|                                                  |
+--------------------------------------------------+
```
Copy:
- Subtitle: "Sing along, get scored, no judgement"

## Screen 2 — Lobby (between songs)

```
+--------------------------------------------------+
|  <   Karaoke Night             [8 in the room]   |
+--------------------------------------------------+
|                                                  |
|   Up next                                        |
|   +--------------------------------------------+ |
|   |  [art]  Creep                              | |
|   |         Radiohead                          | |
|   |         Singer: @meera                     | |
|   |  [Cue song]                                | |
|   +--------------------------------------------+ |
|                                                  |
|   Singer queue (3)                               |
|   1. @meera     Creep                            |
|   2. @arun      Wonderwall                       |
|   3. @sara      Mitwa                            |
|                                                  |
|   [Add me to queue]                              |
|                                                  |
|   Leaderboard this week                          |
|   1. @sara   312                                 |
|   2. @arun   289                                 |
|   3. @meera  271                                 |
+--------------------------------------------------+
```

## Screen 3 — Song Picker

```
+--------------------------------------------------+
|  <   Pick a song                  [Cancel]      |
+--------------------------------------------------+
|  +--------------------------------------------+  |
|  | search...                                  |  |
|  +--------------------------------------------+  |
|                                                  |
|   Trending                                       |
|   o  Creep — Radiohead              [pick]       |
|   o  Wonderwall — Oasis             [pick]       |
|   o  Mitwa — KKR                    [pick]       |
|                                                  |
|   Difficulty                                     |
|   [Easy] [Medium] [Hard]                         |
|                                                  |
|   Stealth mode (hide my score)  [   ]            |
|                                                  |
+--------------------------------------------------+
```

## Screen 4 — Singing (Singer view)

```
+--------------------------------------------------+
|  Creep - Radiohead             [LIVE] [03:24/4:01]|
+--------------------------------------------------+
|                                                  |
|     I wish I was special                         |
|  >> You're so very special <<                    |
|     But I'm a creep                              |
|     I'm a weirdo                                 |
|                                                  |
|     [pulsing mic icon]   Volume bars             |
|                                                  |
|     Listeners (7)                                |
|     [@] [@] [@] [@] [@] [@] [@]                  |
|                                                  |
|     [Stop early]                                 |
+--------------------------------------------------+
```
- Active line highlighted (24 px font, accent color).
- Two preceding + four upcoming lines visible.
- Mic icon pulses in sync with input level (no level → red ring "We can't hear you").

## Screen 5 — Singing (Listener view)

Same lyrics layout but:
- Header shows "Singing: @meera".
- No mic; instead a "Cheer" button that fires a small floating heart emoji into the room.
- "Steal the next song" button if queue has empty slot.

## Screen 6 — Score Reveal

```
+--------------------------------------------------+
|  Creep - Radiohead by @meera                     |
+--------------------------------------------------+
|                                                  |
|              +--------+                          |
|              |   84   |                          |
|              +--------+                          |
|              "Solid take"                        |
|                                                  |
|   Pitch        82 / 100                          |
|   Timing       86 / 100                          |
|   Coverage     91 / 100                          |
|                                                  |
|   [Save replay]   [Next song]                   |
|                                                  |
+--------------------------------------------------+
```
- Score reveal animation: digit roll-up over 1.4 s.
- Score band copy (algorithmic): 0-39 "Brave", 40-69 "Warming up", 70-84 "Solid take", 85-94 "On fire", 95+ "Studio quality".

## Motion Specs
- Lyric line transition: scale 1.0 → 1.08, opacity dim → 1.0, 220 ms.
- Mic input meter: 60 fps, smoothed.
- Cheer hearts: 20 hearts/s max, rise + drift, 1.6 s lifespan.
- Score number roll-up: easeOutQuad, 1.4 s, last 200 ms slight overshoot.
- Queue card insert: slide-in from right 240 ms.

## Copy Library
- "Sing along, get scored, no judgement"
- "Singing: @{name}"
- "We can't hear you — check your mic"
- "Scoring..."
- "Solid take" / "On fire" / "Studio quality"
- "Stealth mode is on — only you see the score"

## Accessibility
- Lyrics font scalable up to 200%; line height locked to 1.4.
- High-contrast lyric mode (white-on-black).
- Screen reader: announces "Now singing line 14 of 60: You're so very special".
- Color blind: active line uses underline, not just color.
- Reduce-motion: disables scale on lyric transitions; uses opacity only.
- Captions / scrolling lyrics double as accessibility aid for hard-of-hearing listeners (they can read along).
- Mic permission prompt with plain-language explanation.
