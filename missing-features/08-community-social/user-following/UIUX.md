# User Following — UI/UX Design

## 1. Design Principles

- Follow button visible from the very first profile glance
- Mutual indicator subtle, not emoji-loud
- Home feed cards reuse the same card grammar as server feed for consistency
- Privacy controls explicit and reversible

## 2. Information Architecture

- Entry points: profile sheet, member context menu, home tab, public profile page
- Parent navigation: bottom-tab Home, slot 2 of 5
- Deep links: `flicko://home`, `flicko://users/:id`, `flicko://me/followers`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Home feed | Aggregated posts from follows | empty, loading, content, error |
| 2 | Profile sheet | Quick follow + mutual | not_following, following, pending |
| 3 | Followers list | Browse followers | content, hidden, empty |
| 4 | Following list | Browse following | content, empty |
| 5 | Follow requests inbox | Approve pending | empty, content |
| 6 | Settings - Follows | Privacy toggles | one |

## 4. Wireframes (ASCII)

### Home feed

```
+--------------------------------------------------+
|  Home                                       (+)  |
+--------------------------------------------------+
|  *For you*   Following   Bookmarked              |
+--------------------------------------------------+
|                                                  |
|  +-- BLOG ----------------------------+           |
|  | @sarah  -  3h  -  Aurora Devs      |           |
|  | "Why we picked Riverpod for v2"    |           |
|  | [hero image]                       |           |
|  | 213 votes  |  44 replies  |  Open  |           |
|  +------------------------------------+           |
|                                                  |
|  +-- TOP MSG ------------------------+           |
|  | @riku   1d  -  Rust Nerds         |           |
|  | "Calendar import bug found, here  |           |
|  | is the trace..."                  |           |
|  +-----------------------------------+           |
|                                                  |
|  +-- RSVP ------------------------+              |
|  | @lex going to Friday Jam       |              |
|  +--------------------------------+              |
+--------------------------------------------------+
|  Pull to refresh                                 |
+--------------------------------------------------+
```

### Profile sheet (not following)

```
+--------------------------------------------------+
|  [avatar]                                        |
|  Sarah Park                              [....]  |
|  @sarah_park   Aurora Devs + 3 servers           |
|                                                  |
|  Builder. Loves Rust + birds.                    |
|                                                  |
|  Followers 1,204     Following 312               |
|                                                  |
|  [    Follow    ]   [  Message  ]                |
|                                                  |
|  Recent public posts                             |
|  - Why we picked Riverpod for v2                 |
|  - Notes from RustConf                           |
+--------------------------------------------------+
```

### Profile sheet (mutual)

```
| [    Following  v    ]   [  Message  ]   <- two-arrow icon shows mutual
|   tap chevron -> menu: Notifications | Mute posts | Unfollow
```

### Followers list

```
+--------------------------------------------------+
| <  Followers (1,204)                             |
+--------------------------------------------------+
| Search _________________                         |
+--------------------------------------------------+
|  @riku        - mutual           [ Follow back ] |
|  @lex                            [ Follow ]      |
|  @nova        - mutual           [ Following v ] |
|  ...                                              |
+--------------------------------------------------+
```

### Follow requests inbox

```
+--------------------------------------------------+
| <  Follow requests (3)                           |
+--------------------------------------------------+
|  @newbie wants to follow you                     |
|     [ Accept ]   [ Decline ]                     |
|                                                  |
|  @hugefan wants to follow you                    |
|     [ Accept ]   [ Decline ]                     |
+--------------------------------------------------+
```

### Settings - Follows

```
+--------------------------------------------------+
| <  Follows                                       |
+--------------------------------------------------+
|  Allow follows              [ on  /  off ]       |
|  Approve each request       [ on  /  off ]       |
|  Show my followers list     [ on  /  off ]       |
|  Show what I follow         [ on  /  off ]       |
|                                                  |
|  Default notifications for new followers:        |
|     ( ) All       (*) Highlights      ( ) None   |
+--------------------------------------------------+
```

## 5. Component Specs

### `FollowButton`
- Props: `state` (none|pending|following|self), `onTap`
- Idle width fits "Follow"; expands to "Requested" or "Following v"
- Long-press shows bell icon for notify-level

### `MutualIcon`
- 14pt two-arrow glyph; tooltip "You both follow each other"

## 6. Empty / Error / Loading

- **Empty home feed:** "Your home feed is quiet. Follow some people to fill it up."
- **Empty followers:** "No followers yet. Share your profile link to grow."
- **Error:** retry banner
- **Loading:** 3 skeleton cards

## 7. Copy

| Surface | Copy |
|---------|------|
| Follow | Follow |
| Following | Following |
| Pending | Requested |
| Empty home | Your home feed is quiet. Follow some people to fill it up. |
| Block tooltip | This user is not accepting follows |
| Approve | Accept |
| Decline | Decline |

## 8. Motion

- Follow tap: button morphs Follow -> Following with check scale 220ms
- Card insert: slide-in 220ms
- Reduced motion: crossfade

## 9. Accessibility

- Follow button announces "Follow {name}" / "Unfollow {name}" / "Follow request pending"
- Mutual icon has Semantics label "Mutual follow"
- Home feed card announces kind, author, age, body preview

## 10. Responsive

- Phone: single column home feed
- Tablet/web: 2-column at 600+

## 11. Theming

- Follow button: filled `primary`; following: outline
- Mutual icon tinted `tertiary`
