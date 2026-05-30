# Clips System — UI / UX

Three core screens: Clip Capture sheet, Clip Detail page, Clips Feed (vertical).

Tokens reuse Flicko base. Vertical clip surfaces use a darker `surface/0` `#08080C` to make video pop. Accent stays `#FF4D6D`.

---

## Screen 1: Clip Capture sheet (in live player)

Bottom sheet over the live player. Player keeps playing muted in background.

```
+-----------------------------------------------------------+
|  Clip last...                                          X  |
+-----------------------------------------------------------+
|                                                           |
|     [ 30s ]   [ 60s ]   [ 90s ]   [ Custom 5–300s ]      |
|                                                           |
|  Custom range                                             |
|  [ ============O======================== ]                |
|              60 s                                         |
|                                                           |
|  Title (optional)                                         |
|  [ chat going wild at 1080p                       ]      |
|  32 / 80                                                  |
|                                                           |
|  Cover                                                    |
|  [ thumb ]  [ thumb ]  [ thumb* ]  [ thumb ]  [ thumb ]   |
|                                                           |
|                                       (Cancel)  ( Clip )  |
+-----------------------------------------------------------+
```

Copy:
- Header: "Clip last..."
- Submit button label changes to "Clipping..." with an inline spinner during the 9 s SLA window.
- After success, button area is replaced by:

```
| ✓ Your clip is ready                                     |
| [ thumbnail 16:9 small ]  Open  ·  Copy link  ·  Share   |
```

- Failure copy: "Couldn't render that clip. The stream may have hiccuped — try a shorter range or another moment."

Motion:
- Sheet slides up 240 ms ease-out.
- Length pill press: 100 ms scale down to 0.96, springs back.
- Submit button morphs into a progress pill with circular progress around the spinner; never a full-screen blocker.

A11y:
- Length pills are a `radiogroup`.
- Slider has `aria-valuemin=5 aria-valuemax=300` and announces seconds.
- "Clipping..." state announces via `aria-live=polite` after 1 s so screen readers don't get spammed by network jitter.
- Cover thumbnails are buttons with `aria-label="Use frame at 0:35 as cover"`.

---

## Screen 2: Clip Detail page

Vertical-first, but adapts to landscape clips.

```
+-------------------------------------------------------------+
|  <-                                              (more)     |
+-------------------------------------------------------------+
|                                                             |
|                                                             |
|         [   VIDEO 9:16, autoplay loop, muted   ]            |
|                          (tap to unmute)                    |
|                                                             |
|                                                             |
+-------------------------------------------------------------+
|  Clip from "Sunday Stream — building the VOD player"        |
|  @aria        clipped by @marko        2 min ago            |
+-------------------------------------------------------------+
|  ❤ 142     ↻ 21      ⬇ 88      ↗ Share                    |
+-------------------------------------------------------------+
|  Watch full stream  ->                                      |
+-------------------------------------------------------------+
```

Copy:
- Title prefix: "Clip from \"<stream title>\""; if creator overrides title, show that instead.
- Attribution row: "@aria  clipped by @marko" — the streamer is bigger and pink, the clipper smaller and gray.
- Share menu items: "Copy link", "Share to X", "Share to TikTok", "Share to Discord", "More".

Motion:
- Tap-to-unmute pulses a 100% white circle outline around the video first 1.5 s, then fades.
- Like button bursts into 6 small heart particles on first like (one-shot, respects reduce-motion).
- Bottom action bar lifts 12 px on focus to clear the home indicator.

A11y:
- Video has `aria-label` of the full title and is keyboard pausable with space.
- Action counts have human labels: "142 likes" not just "142".
- Share menu uses native share sheet on iOS/Android, dropdown on web, with full keyboard nav.

---

## Screen 3: Clips Feed (vertical)

Reached from the bottom nav "Clips" tab. Snap-scroll, one clip per viewport.

```
+-------------------------------------------------------------+
|  For You    Following    Trending                           |
+-------------------------------------------------------------+
|                                                             |
|                                                             |
|             [  full-bleed 9:16 video, looped  ]             |
|                                                             |
|                                                  ❤  142    |
|                                                  ↻   21    |
|                                                  ⬇   88    |
|                                                  ↗  Share   |
|                                                             |
|  @aria · LIVE NOW                                           |
|  Sunday Stream — building the VOD player                    |
|  ===O============================ 0:42 / 1:00              |
+-------------------------------------------------------------+
```

Copy:
- Tab labels: "For You", "Following", "Trending". Long press a tab pins it as the launch tab.
- "LIVE NOW" badge if the source stream is still live; tap takes the viewer into the live player.
- Empty For You: "Follow a few creators and we'll fill this feed with their best moments."

Motion:
- Vertical snap with rubber-band overscroll. 220 ms spring.
- Cross-fade audio between clips during the 60 ms transition window so there is no abrupt silence.
- Pre-buffer the next clip's first 2 s while the current one plays.

A11y:
- Each clip is a `region` with `aria-roledescription="short clip"`.
- Reduce-motion disables auto-advance; viewer must tap "Next" button which appears at the bottom-right.
- Captions (when available) on by default if OS pref is on; toggleable via long-press.
- Each action button is reachable via on-screen-controls keyboard (D-pad on TV, arrow keys on web).

---

## Cross-screen rules

- Skeletons: 2-line title placeholder + 9:16 dark gradient. No spinner.
- Errors: snackbar "Couldn't load clip" with "Retry" action; do not navigate away.
- Network: degrade to 540p mp4 transcode if `effectiveType` < 4g; we ship a `_540.mp4` alongside the main mp4.
- Hit targets all >= 44x44 logical pixels.

## Microcopy library

| Context | Copy |
|---|---|
| Sheet title | "Clip last..." |
| Custom range hint | "5 s to 5 min" |
| Submit button | "Clip" -> "Clipping..." -> "Open clip" |
| Success toast | "Saved to your clips" |
| Failure toast | "Couldn't render. Try again?" |
| Share menu header | "Send this clip" |
| Report dialog | "What's wrong with this clip?" with reasons (Sexual, Violence, Hate, Self-harm, Spam, Other) |
| Removed clip page | "This clip is no longer available." |
