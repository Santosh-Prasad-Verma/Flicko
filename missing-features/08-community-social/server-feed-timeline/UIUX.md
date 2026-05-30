# Server Feed Timeline — UI/UX Design

## 1. Design Principles

- Match Flicko's existing dark/light theme tokens (see `mobile/lib/core/theme/`)
- Reuse `ServerCard`, `Avatar`, `VoteArrows` from `mobile/lib/features/shared/presentation/widgets/`
- Motion: Material Motion easings; respect `reduced-motion` flag
- Accessibility: every interactive element has Semantics label and >=44pt tap target
- Density: cards must not exceed 240pt before "Show more"

## 2. Information Architecture

- Entry points: server home tab (default landing), server drawer, deep link
- Parent navigation: per-server bottom nav, slot 1 of 4 (Feed | Channels | Members | Events)
- Deep link: `flicko://server/<server_id>/feed`
- Card tap deep link: `flicko://server/<server_id>/feed/<item_id>` then routes to source

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Server Feed | Aggregated timeline | empty, loading, content, error, offline |
| 2 | Catch-up sheet | Bottom sheet of unread since last visit | empty, content |
| 3 | Feed analytics (owner) | Per-item view/click metrics | content, empty |
| 4 | Pin manager | Reorder pinned cards | content |

## 4. Wireframes (ASCII)

### Screen 1 — Server Feed (Top tab)

```
+--------------------------------------------------+
| <  Aurora Devs                            ...    |
+--------------------------------------------------+
|  For you  |   New   |  *Top*                     |
+--------------------------------------------------+
|  +-- Catch up: 14 new since Tue ---------+  |     |
|  |  Tap to scroll to your last visit     |  |     |
|  +---------------------------------------+      |
|                                                  |
|  +-- PINNED -------------------------------+   |
|  | [#] announcements                       |   |
|  | "v2 launch is live, read the changelog" |   |
|  | by @sarah  2d  *3*  213 votes  44 reply |   |
|  +-----------------------------------------+   |
|                                                  |
|  +-- Forum post --------------------------+    |
|  | [F] design                             |    |
|  | "Logo refresh proposal"                |    |
|  | image preview                          |    |
|  | by @riku  9h  187 votes  21 replies    |    |
|  +----------------------------------------+    |
|                                                  |
|  +-- Event ------------------------------+     |
|  | [E] Friday Jam Session                |     |
|  | Fri 6pm UTC  RSVP  84 going           |     |
|  +----------------------------------------+    |
|                                                  |
|  +-- Top message -----------------------+      |
|  | [#] random                           |      |
|  | "Found a bug in the calendar import" |      |
|  | by @lex  3h  12 votes  jump to chat  |      |
|  +---------------------------------------+     |
+--------------------------------------------------+
|  Pull to refresh  *  long-press to hide          |
+--------------------------------------------------+
```

### Screen 2 — Catch-up bottom sheet

```
+--------------------------------------------------+
|        Catch up since Tue 10:42 AM         [X]   |
+--------------------------------------------------+
|  14 new items                                    |
|  +- 3 announcements                              |
|  +- 5 forum posts                                |
|  +- 2 events scheduled                           |
|  +- 4 top messages                               |
|                                                  |
|  [ Mark all read ]   [ Open feed ]               |
+--------------------------------------------------+
```

### Screen 3 — Owner analytics

```
+--------------------------------------------------+
| <  Feed analytics                                |
+--------------------------------------------------+
|  Last 7 days       impressions   clicks   ctr    |
|  v2 launch ann.       12,431       2,108  17%    |
|  Logo refresh         9,021        1,604  18%    |
|  Friday jam            8,442         766   9%    |
|  Calendar bug          5,901         911  15%    |
|                                                  |
|  Tap row for time series                         |
+--------------------------------------------------+
```

## 5. Component Specs

### `FeedCard`
- Props: `kind`, `title`, `preview`, `mediaUrls`, `voteScore`, `replyCount`, `author`, `createdAt`, `pinned`
- States: idle, hover (web), pressed, dismissed (swipe), hidden
- Token usage: `colorScheme.surface`, `colorScheme.outlineVariant`, `textTheme.titleMedium`
- Long-press shows context menu: Pin, Hide, Report, Copy link

### `CatchUpBanner`
- Props: `unreadCount`, `lastVisitAt`
- Collapses on scroll past

### `VoteArrows`
- Reuses global vote widget; disabled per channel-config

## 6. Empty / Error / Loading

- **Empty:** illustration of an empty bulletin board, copy "Nothing pinned yet. Owners can pin posts to the top of the feed."
- **Error:** inline banner above the list, retry button, never blocks content
- **Loading:** 5 skeleton cards, shimmer 1200ms cycle

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Feed |
| Tabs | For you / New / Top |
| Empty | No posts yet. Pin one to get the feed started. |
| CTA | Pin a post |
| Error | Could not load the feed. Check your connection. |
| Catch-up label | Catch up since {time} |
| Mark read | Mark all read |
| Hide | Not interested |
| Pinned chip | PINNED |

Voice: friendly, concise, second-person. No jargon.

## 8. Motion

- Card insert: slide-in from top, 220ms easeOutCubic
- Pin badge: scale 0.9 -> 1.0, 180ms
- Tab switch: shared-axis X, 300ms
- Reduced motion: replace slide with crossfade

## 9. Accessibility

- Each card announces "kind, title, by author, age, vote count"
- Pin/hide context menu reachable via long-press and double-tap-then-action
- Color contrast >=4.5:1 for body text; pinned chip uses surface-tint with 3:1 large text
- Live region announces "{N} new items added" when realtime push lands

## 10. Responsive

- Phone: single column, full-bleed cards
- Foldable cover: same as phone
- Tablet/web: 2-column masonry at 600+, 3-column at 1200+
- Web: keyboard arrows navigate cards, Enter opens

## 11. Theming

- Light, Dark, AMOLED variants
- Pinned chip uses the server accent color (tint, not solid)
- Honor server `accent_color` when `09-customization/accent-colors` is enabled
