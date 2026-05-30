# Home Screen Widgets — UI/UX Design

## 1. Design Principles

- Native widget look on each platform: SF Symbols and SF Pro on iOS, Material You dynamic color on Android 12+.
- Match Flicko brand only on accent dot and avatar ring; chrome stays system-default so the widget sits naturally on any home screen.
- No motion inside the widget face (platform forbids most animation anyway). Use system tint changes only.
- Tap targets: minimum 44pt iOS / 48dp Android per cell. Quick reply field uses platform standard text intent UI.
- Accessibility: every cell has accessibility label + value. VoiceOver reads "5 unread mentions in Game Devs, double-tap to open."

## 2. Information Architecture

Where this feature lives:
- Entry points: home screen (primary), Settings -> Notifications -> Widgets (configuration), onboarding tooltip on day-3 retention check-in.
- Parent navigation: native OS widget gallery.
- Deep links:
  - `flicko://channel/<server_id>/<channel_id>`
  - `flicko://dm/<thread_id>`
  - `flicko://dm/<thread_id>?compose=1&body=<encoded>`
  - `flicko://server/<server_id>`
  - `flicko://friend/<user_id>`
  - `flicko://settings/widgets`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Unread Pulse face S | total unread badge | empty (0), content, stale, signed-out |
| 2 | Unread Pulse face M | per-server breakdown | as above |
| 3 | Unread Pulse face L | full top-8 list | as above |
| 4 | Quick Reply face M | last DM + reply button | empty, content, stale |
| 5 | Recent Server face S/M | server icons grid | empty, content |
| 6 | Friend Status face M/L | friend tiles | empty, content |
| 7 | Widget Config screen (in-app) | user toggles | loading, content, saved |

## 4. Wireframes (ASCII)

### Unread Pulse — Small (2x2)
```
+------------------------+
|  Flicko       12:04 PM |
|                        |
|         17             |
|       unread           |
|                        |
|  3 mentions            |
+------------------------+
```

### Unread Pulse — Medium (4x2)
```
+--------------------------------------------+
|  Flicko unread                17 / 3 @     |
+--------------------------------------------+
|  [G] Game Devs           5  *  1 mention   |
|  [F] Friends             4                 |
|  [W] Work                3                 |
|  [B] Book Club           2                 |
+--------------------------------------------+
```

### Unread Pulse — Large (4x4)
```
+--------------------------------------------+
|  Flicko unread                17 / 3 @     |
+--------------------------------------------+
|  [G] Game Devs                5   *  1 @   |
|  [F] Friends                  4            |
|  [W] Work                     3            |
|  [B] Book Club                2            |
|  [N] News                     1            |
|  [M] Music                    1            |
|  [I] Indie Hackers            1            |
|  [Q] Q&A                      0            |
+--------------------------------------------+
|  updated 4m ago    open Flicko ->          |
+--------------------------------------------+
```

### Quick Reply — Medium (4x2)
```
+--------------------------------------------+
|  (avatar)  Aisha               9:55 AM     |
|            "see you at 7?"                 |
+--------------------------------------------+
|  [ Type a reply...                  Send ] |
+--------------------------------------------+
```
Tapping the field deep-links to compose pre-filled. Send is a separate intent on Android (Glance action), iOS opens app to composer (no inline send pre-iOS-17 InteractiveWidgets fallback).

### Recent Server — Small (2x2)
```
+----------------+
| [G][F][W][B]   |
| (4 icons,      |
|  unread dots)  |
+----------------+
```

### Recent Server — Medium (4x2)
```
+----------------------------------+
| [G]   [F]   [W]   [B]   [N]   [M]|
|  *           *           *       |
| Game  Frnds  Work  Book  News Mus|
+----------------------------------+
```

### Friend Status — Medium (4x2)
```
+--------------------------------------------+
| (av) Aisha       online    "coding"        |
| (av) Ben         idle      "lunch"         |
| (av) Carla       offline   2h ago          |
+--------------------------------------------+
```

### Friend Status — Large (4x4)
```
+--------------------------------------------+
| (av)Aisha    online    "coding"            |
| (av)Ben      idle      "lunch"             |
| (av)Carla    offline   2h ago              |
| (av)Dom      online                        |
| (av)Eli      dnd       "head down"         |
| (av)Faye     online    "deploying"         |
+--------------------------------------------+
```

### Widget Config (in-app)
```
+--------------------------------------------+
|  <  Widget Settings                        |
+--------------------------------------------+
|  Counted in unread total                   |
|   [x] Game Devs                            |
|   [x] Friends                              |
|   [ ] Work                                 |
|   [x] Book Club                            |
|                                            |
|  Pinned friends (up to 6)                  |
|   [+ pick from list]                       |
|   - Aisha     (x)                          |
|   - Ben       (x)                          |
|                                            |
|  [x] Show DM preview text                  |
|  [ ] Mentions only                         |
|                                            |
|  Refresh now                               |
+--------------------------------------------+
```

## 5. Component Specs

### `WidgetFacePreviewCard`
- Props: `face: WidgetFace`, `size: WidgetSize`, `digest: WidgetDigest`.
- Renders an in-app preview that mirrors the native face 1:1 so users can see what the widget will look like before pinning.
- States: idle / loading-shimmer / stale / error.
- Token usage: `colorScheme.surfaceContainer`, `textTheme.titleSmall`.

### `ServerUnreadRow` (M/L face)
- Avatar 24pt + name 14pt + unread count + optional mention badge.
- Tap area covers full row.

### `FriendPresenceDot`
- 8pt circle; colors via `presenceColor(status)` shared with main app.

## 6. Empty / Error / Loading

- **Empty (0 unread):** big check-mark glyph + "All caught up" — keeps widget useful even at zero state.
- **Signed-out:** Flicko logo + "Tap to sign in" deep link to `flicko://auth`.
- **Error:** show last cached + small "stale" pill.
- **Loading (first install only):** skeleton blocks for ~1s while initial digest fetches.

## 7. Copy

| Surface | Copy |
|---------|------|
| Empty unread | "All caught up" |
| Signed-out | "Tap to sign in" |
| Stale | "updated 12m ago" |
| Quick reply placeholder | "Type a reply" |
| Config save toast | "Widgets refreshed" |
| Error fallback | "Open Flicko to refresh" |

Voice: friendly, direct, second-person. No exclamation marks.

## 8. Motion

- Widget itself: no motion (platform constraint).
- In-app preview card: 150ms crossfade when digest updates.
- Config save: 200ms slide-down toast.

## 9. Accessibility

- Each row exposes a single semantic action with combined label "Game Devs, 5 unread, 1 mention, opens server".
- Friend tile: "Aisha, online, status coding, opens DM".
- Quick reply field: standard TextField semantics; supports VoiceOver dictation.
- Color contrast: presence dots paired with text suffix ("online", "idle") for color-blind users.
- Reduced motion respected via system flag.
- Dynamic type honored on iOS up to xxxLarge; lines truncate with ellipsis past that.

## 10. Responsive

- iOS supports systemSmall (155x155), systemMedium (329x155), systemLarge (329x345). Renders are pixel-tuned for iPhone SE (smallest) and iPhone 15 Pro Max.
- Android Glance supports 2x2, 4x2, 4x4 with auto-resize via `SizeMode.Exact`.
- Foldable Android (Pixel Fold inner display): full M/L rendered without rescale.

## 11. Theming

- iOS: respects light/dark via `colorScheme(.light/.dark)`. Tinted Mode (iOS 18) handled by providing monochrome glyph variants in asset catalog.
- Android: `dynamicColorScheme()` from Material You wallpaper extraction; AMOLED black variant auto-applied at <5% screen brightness preset.
- Honors server accent color only on Recent Server face's icon ring (when `09-customization/accent-colors` ships).
