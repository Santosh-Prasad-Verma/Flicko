# VOD Storage — UI / UX

Three core screens: VOD Player, Creator VOD Library, VOD Settings (privacy + delete).

Design tokens reuse the Flicko system: `surface/0` `#0E0E12`, `surface/1` `#16161E`, `accent` `#FF4D6D`, `text/hi` `#F5F5F7`, `text/lo` `#9A9AA8`. Body type Inter 14/20, headline Space Grotesk 22/28.

---

## Screen 1: VOD Player

Full-bleed video on top, metadata + chapter rail below.

```
+-------------------------------------------------------------+
| <-                                       (cast) (more)      |
+-------------------------------------------------------------+
|                                                             |
|                                                             |
|                  [   VIDEO SURFACE 16:9   ]                 |
|                                                             |
|                                                             |
|   00:14:22  =====O=====================  02:11:48          |
|              [ <- 10s ] [pause] [ +10s ]    [HD] [cc] [⤢]  |
+-------------------------------------------------------------+
| Sunday Stream — building the VOD player                     |
| @aria   42,108 views   2 days ago             (subscribe)   |
+-------------------------------------------------------------+
| Chapters                                                    |
| 00:00  Cold open                                            |
| 04:12  Why HLS over DASH                                    |
| 27:50  Wiring Azure Media Egress              <- current        |
| 1:14:09  Q&A                                                |
+-------------------------------------------------------------+
| Tip   Clip   Share   Save                                   |
+-------------------------------------------------------------+
```

Copy:
- Title field is 1 line, ellipsized at 64 chars on mobile, full on tablet.
- Subscribe button: "Subscribe", post-action "Subscribed" with check mark for 1.5 s, then settles to "Subscribed" outline.
- Empty chapter state copy: "Chapters are still being generated. Check back in a few minutes."

Motion:
- Player chrome fades out after 2.5 s idle, eases in on tap (180 ms cubic-bezier(.2,.8,.2,1)).
- Chapter row scrolls into view with a 120 ms slide as playback crosses the boundary.
- Scrub thumbnail pops with 8 px translate-y and 0 -> 1 opacity (140 ms).

A11y:
- All controls keyboard reachable (Tab order: back, cast, more, scrub, prev, play, next, quality, cc, fullscreen).
- Scrubber announces `aria-valuenow` in seconds and a human-readable `aria-valuetext` ("1 hour 14 minutes 9 seconds").
- Captions default-on if device caption setting is on (iOS/Android caption-pref API).
- Color contrast on chrome 4.7:1 minimum; chapter "current" indicator does not rely on color alone — there is an arrow.
- Reduce-motion replaces the scrub thumbnail pop with an instant render.

---

## Screen 2: Creator VOD Library

Reached from creator profile -> "VODs" tab. Grid of cards, sort and filter chips.

```
+-------------------------------------------------------------+
|  @aria's VODs                                               |
|  [ Newest ▾ ]  [ All ▾ ]  [ Public ]  [ Subs only ]         |
+-------------------------------------------------------------+
|  +------------+  +------------+  +------------+             |
|  | thumb 16:9 |  | thumb 16:9 |  | thumb 16:9 |             |
|  | 2:11:48    |  | 0:48:22    |  | 4:02:01    |             |
|  | Sunday...  |  | Hotfix...  |  | Marathon..|             |
|  | 42k · 2d   |  | 8.1k · 5d  |  | 121k · 1w |             |
|  +------------+  +------------+  +------------+             |
|                                                             |
|  +------------+  +------------+  +------------+             |
|  |   ...      |  |   ...      |  |   ...      |             |
|  +------------+  +------------+  +------------+             |
+-------------------------------------------------------------+
| (load more)                                                 |
+-------------------------------------------------------------+
```

Copy:
- Empty state: "@aria hasn't streamed yet. Tap follow and we'll ping you when they go live."
- Processing state on a card: "Processing... ready in ~3 min" with a subtle shimmer over the thumb.

Motion:
- Cards stagger-fade in (60 ms each, max 8 cards animated) on first paint.
- Long-press on a card opens a contextual sheet (creator only): Edit, Make private, Delete.

A11y:
- Each card is a single tappable target; the duration badge has `aria-label="2 hours 11 minutes"`.
- Filter chips are radiogroups with `role="radio"`.

---

## Screen 3: VOD Settings (creator only)

Modal sheet from the player's "more" menu, or from the library card long-press.

```
+-------------------------------------------------------------+
|  Edit VOD                                              X    |
+-------------------------------------------------------------+
|  Title                                                      |
|  [ Sunday Stream — building the VOD player        ]         |
|  64 / 100                                                   |
|                                                             |
|  Description                                                |
|  [ multiline...                                   ]         |
|                                                             |
|  Visibility                                                 |
|  ( ) Public                                                 |
|  (•) Unlisted   anyone with the link                        |
|  ( ) Subscribers only                                       |
|  ( ) Private    only you                                    |
|                                                             |
|  Chapters                                                   |
|  [ Auto (Whisper) ▾ ]   regenerate                          |
|                                                             |
|  Danger zone                                                |
|  [ Delete VOD ]                                             |
+-------------------------------------------------------------+
|                                            ( Cancel ) (Save)|
+-------------------------------------------------------------+
```

Copy:
- Delete confirm copy: "This VOD will be moved to trash and permanently removed in 24 hours. This cannot be undone after that."
- Save success toast: "Saved. Changes are live."

Motion:
- Sheet slides up 280 ms, dismisses with the same curve.
- Save button shows an inline spinner inside the button label, never blocks the whole sheet.

A11y:
- Radio group for visibility uses native `role=radiogroup`.
- Title char counter is `aria-live=polite` so screen readers announce remaining chars only when within 10 of the limit.
- Delete button has a destructive role and confirms in a separate alert dialog.

---

## Cross-screen rules

- Loading: skeleton blocks for thumb + 2 lines of text, never a centered spinner.
- Errors: inline banner under the player or above the library grid, with a "Try again" button.
- Network: if offline and a VOD was started, keep the last decoded frame and show "Reconnecting..." pill (does not pause the buffer).
