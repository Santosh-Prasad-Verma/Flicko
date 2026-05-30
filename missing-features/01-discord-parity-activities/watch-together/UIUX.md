# Watch Together — UI/UX

## Design Principles
- Mobile-first, portrait-default. Player is the hero; controls collapse.
- Host wears a subtle crown; everyone else is a viewer.
- Latency is invisible when working, surfaced when broken.
- Reactions float, never block the frame.

## Screen 1 — Activity Picker (entry from voice room)

```
+--------------------------------------------------+
|  < Back     Start an Activity        ...         |
+--------------------------------------------------+
|                                                  |
|  [ ] Watch Together         (Host)               |
|      Sync videos with up to 12 friends           |
|      [Start]                                     |
|                                                  |
|  [ ] Music Party                                 |
|  [ ] Karaoke Night                               |
|  [ ] Gartic Phone                                |
|  [ ] More from Activities Hub                    |
|                                                  |
+--------------------------------------------------+
```
Copy:
- Title: "Start an Activity"
- WT subtitle: "Sync videos with up to 12 friends"
- CTA: "Start"

## Screen 2 — Paste / Pick Source

```
+--------------------------------------------------+
|  Cancel        Watch Together         Next       |
+--------------------------------------------------+
|                                                  |
|   Paste a YouTube, Vimeo or video link           |
|  +--------------------------------------------+  |
|  | https://youtu.be/...                       |  |
|  +--------------------------------------------+  |
|                                                  |
|   Or pick from your library                      |
|  +--------+ +--------+ +--------+               |
|  |  thumb | |  thumb | |  thumb |               |
|  | Title  | | Title  | | Title  |               |
|  +--------+ +--------+ +--------+               |
|                                                  |
|   Recent in this room                            |
|  - Wedding reel.mp4 (2d ago)                    |
|                                                  |
+--------------------------------------------------+
```
Validation:
- Inline error if URL is non-allowlisted: "We can play YouTube, Vimeo and direct video links."
- Loading state shows skeleton thumb in 200 ms.

## Screen 3 — Player (Host view)

```
+--------------------------------------------------+
|  <  Title of Video           [HOST] [12 viewers] |
+--------------------------------------------------+
|                                                  |
|     +------------------------------------+       |
|     |                                    |       |
|     |          VIDEO FRAME               |       |
|     |        (16:9 letterboxed)          |       |
|     |                                    |       |
|     +------------------------------------+       |
|     [<<10s]  [ ||  ]  [10s>>]   1.0x             |
|     |======*-----------------------|              |
|     03:24                          14:30         |
|                                                  |
|   Reactions:  [LOVE] [LAUGH] [WOW] [SAD] [FIRE]  |
|                                                  |
|   Viewers (12)                                   |
|   [@] [@] [@] [@] [@] [@] [@] [@] [@] [@] [@]   |
|                                                  |
|   [Hand off host]   [End for everyone]           |
+--------------------------------------------------+
```

## Screen 4 — Player (Viewer view)

Same as host but:
- Scrubber is read-only, faded.
- Play/pause buttons hidden; show "Host: @amrita" tag.
- "Request seek" affordance behind tap-and-hold.
- Sync indicator: green dot "in sync" / amber "catching up" / red "out of sync, tap to resync".

## Motion Specs
- Player mounts: 240 ms ease-out, slight scale from 0.96 to 1.
- Reactions: emoji rises 220 px over 1.6 s, fades out last 0.4 s, slight horizontal drift.
- Drift indicator pulse: 2 s loop, opacity 0.6 to 1.0.
- Host crown badge: 600 ms shimmer once on assignment.
- Toast for host change: slides from top, 320 ms, lingers 3.5 s.

## Empty / Edge States
- No active session, voice room only: Activities Hub button hint at bottom.
- Source unsupported: error card "We can't play this link. YouTube, Vimeo, and direct MP4/HLS work."
- Network drop: full-screen toast "Reconnecting..." with retry; auto resumes within 4 s.
- Host left, you became host: modal "You're the host now. Pause for snacks?" with [OK].

## Copy Library
- "Sync videos with up to 12 friends"
- "Host: @{name}"
- "Catching up..."
- "Out of sync — tap to resync"
- "You're the host now."
- "End for everyone?"
- "Hand off host to..."

## Accessibility
- All controls min 44x44 px tap target.
- Captions toggle for YouTube/HTML5 (CC button when track exists).
- Screen reader labels: "Play, host control", "Seek bar, host only", "Viewer count, twelve".
- Reduce-motion: disables emoji rise; uses fade.
- Color blind safe: sync states use icon plus color (dot, triangle, circle-with-slash).
- Dynamic text size up to 200% without truncation in viewer list.
- High-contrast theme: 4.5:1 minimum on all overlay text.
