# Music Party — UI/UX

## Design Principles
- The currently playing track is the hero. Everything else orbits.
- Queue is collaborative; anyone can add, only DJ reorders.
- DJ identity is celebrated, not hidden — show the badge, the avatar, the energy.
- Free-tier preview state is honest, not punitive.

## Screen 1 — Activity Picker entry

```
+--------------------------------------------------+
|  < Back     Start an Activity                    |
+--------------------------------------------------+
|                                                  |
|  [ ] Music Party              [Start]            |
|      Queue tracks, take turns DJing              |
|      Spotify required for full tracks            |
|                                                  |
+--------------------------------------------------+
```
Copy:
- Subtitle: "Queue tracks, take turns DJing"
- Disclosure: "Spotify required for full tracks"

## Screen 2 — Now Playing (DJ view)

```
+--------------------------------------------------+
|  <   Music Party              [DJ] [10 listening]|
+--------------------------------------------------+
|                                                  |
|         +--------------------+                   |
|         |                    |                   |
|         |    ALBUM ART       |                   |
|         |    320x320         |                   |
|         |                    |                   |
|         +--------------------+                   |
|                                                  |
|     Cardigan                                     |
|     Taylor Swift   .   folklore                  |
|                                                  |
|     |======*------------------|                  |
|     1:18                       3:59              |
|                                                  |
|   [<<]   [ pause ]   [skip >>]                  |
|                                                  |
|   Vibe:  [HEART]  [FIRE]  [STAR]   Skip vote (3) |
|                                                  |
|   Up next                                        |
|   1.  Anti-Hero - Taylor Swift   . added by Aman |
|   2.  Flowers - Miley Cyrus      . added by Sara |
|   3.  + add a track                              |
|                                                  |
|   [Hand off DJ]                                  |
+--------------------------------------------------+
```

## Screen 3 — Now Playing (Listener view)

Same layout, but:
- No play/pause/skip controls.
- Shows DJ avatar pinned: "DJ: @aman"
- "Skip vote" tap counts toward threshold.
- "Add to queue" prominent.
- If free-tier: chip "Preview only — Get Spotify" linking to OAuth.

## Screen 4 — Queue & Search

```
+--------------------------------------------------+
|  <   Add a track                  [Cancel]      |
+--------------------------------------------------+
|  +--------------------------------------------+  |
|  | search Spotify...                          |  |
|  +--------------------------------------------+  |
|                                                  |
|   Top hits                                       |
|   o  Espresso - Sabrina Carpenter   [+]          |
|   o  Birds of a Feather - Billie    [+]          |
|   o  Style - Taylor Swift           [+]          |
|                                                  |
|   Recently played in this room                   |
|   o  Cardigan - Taylor Swift                     |
|                                                  |
+--------------------------------------------------+
```

## Screen 5 — DJ Rotation Settings

```
+--------------------------------------------------+
|  Settings                              [Save]    |
+--------------------------------------------------+
|                                                  |
|   Rotation                                       |
|   ( ) Manual — DJ stays until handoff            |
|   (o) Round-robin — switch each track            |
|   ( ) Listener vote                              |
|                                                  |
|   Skip vote threshold                            |
|   |--------*------|   50%                        |
|                                                  |
|   Max listeners        25                        |
|                                                  |
+--------------------------------------------------+
```

## Motion Specs
- Album art enters: scale 0.9 to 1.0 over 320 ms, ease-out.
- Track change: cross-fade 280 ms; old art slides up 12 px while fading.
- Reaction taps: small particle burst at button (1 s, 12 particles).
- DJ handoff: avatar swap with shimmer ring 600 ms.
- Skip-vote progress: ring fills clockwise as votes climb.
- Queue reorder: drag handle, lift shadow on touch, 180 ms settle on drop.

## Copy Library
- "Queue tracks, take turns DJing"
- "DJ: @{name}"
- "Preview only — Get Spotify"
- "Skip vote? {n} of {threshold}"
- "Round-robin: next DJ is @{name}"
- "No queue. Add a track to start."

## Accessibility
- Album art has alt text "Album art for {title} by {artist}".
- Scrubber announces "Position one minute eighteen of three minutes fifty-nine".
- Tap targets 44x44.
- Color blind safe vibe icons (heart/fire/star plus distinct shape).
- Reduce-motion: disable particle bursts, swap with pulse.
- Live region announces "Now playing: {title} by {artist}, DJ {name}".
- Dynamic text up to 200% across now-playing card without breaking layout.
