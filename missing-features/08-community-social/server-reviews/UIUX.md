# Server Reviews — UI/UX Design

## 1. Design Principles

- Reviews live on the discovery page, not buried in settings
- Stars are big and tactile in compose; small and dense in list
- Owner replies clearly distinguished with badge and indent
- Composer respects mobile thumb zone; primary CTA bottom-right

## 2. Information Architecture

- Entry points: discovery server card, server profile page (public), in-server "About" tab
- Parent navigation: Discover -> Server -> Reviews tab
- Deep link: `flicko://discovery/server/<id>/reviews`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Reviews list | Browse and sort reviews | empty, loading, content, error |
| 2 | Compose | Submit/edit a review | draft, submitting, error |
| 3 | Eligibility modal | Explain why they cannot yet review | one |
| 4 | Owner reply sheet | Reply to a review | draft, submitting |
| 5 | Report dialog | Report a review | reasons list |

## 4. Wireframes (ASCII)

### Screen 1 — Reviews list

```
+--------------------------------------------------+
| <  Aurora Devs - Reviews                         |
+--------------------------------------------------+
|                                                  |
|   *****  4.6                                     |
|   128 reviews                                    |
|                                                  |
|   5  ##############################  100         |
|   4  #####                            18         |
|   3  ##                                5         |
|   2  #                                 3         |
|   1  #                                 2         |
|                                                  |
|  [ Write a review ]                              |
|                                                  |
|  Sort:  *Helpful*  Newest  Lowest  Highest       |
+--------------------------------------------------+
|                                                  |
|  +-- review card -----------------------------+  |
|  | @riku  ***** 5  -  3d ago      [helpful 12]|  |
|  | Best Rust community I've found, super      |  |
|  | active and welcoming to beginners.         |  |
|  |   |-- Owner reply by @sarah  -  2d ago     |  |
|  |   |-- Thanks Riku, glad you joined!         |  |
|  +--------------------------------------------+  |
|                                                  |
|  +-- review card -----------------------------+  |
|  | @lex   ****  4  -  1w           [helpful 4]|  |
|  | Solid mods, sometimes a bit quiet weekends.|  |
|  +--------------------------------------------+  |
+--------------------------------------------------+
```

### Screen 2 — Compose review

```
+--------------------------------------------------+
| <  Write a review for Aurora Devs                |
+--------------------------------------------------+
|                                                  |
|   Tap a star to rate                             |
|       *  *  *  *  *                              |
|                                                  |
|   What stood out? (optional)                     |
|  +--------------------------------------------+  |
|  | I joined a month ago and the help channel  |  |
|  | got me unstuck within an hour. The events  |  |
|  | are well-organized.                        |  |
|  +--------------------------------------------+  |
|   180 / 1000 chars                               |
|                                                  |
|   Your review is public and shows your handle.   |
|                                                  |
|                              [ Submit review ]   |
+--------------------------------------------------+
```

### Screen 3 — Eligibility modal

```
+----------------------------------------+
|  Almost there                          |
+----------------------------------------+
|  You can review this server once you   |
|  have been a member for 14 days and    |
|  posted 20 messages.                   |
|                                        |
|  Your progress:                        |
|    Membership:  6 / 14 days            |
|    Messages:    13 / 20                |
|                                        |
|  [ Got it ]                            |
+----------------------------------------+
```

### Screen 4 — Owner reply sheet

```
+--------------------------------------------------+
|  Reply to @riku's review                         |
+--------------------------------------------------+
|  +--------------------------------------------+  |
|  | Thanks for the kind words. Glad you joined!|  |
|  +--------------------------------------------+  |
|                                                  |
|                              [ Post reply ]      |
+--------------------------------------------------+
```

## 5. Component Specs

### `RatingStars`
- Props: `value`, `interactive`, `size`
- Tap to set rating, drag to refine on long-press
- Token: `colorScheme.tertiary` for filled, `outlineVariant` for empty

### `ReviewCard`
- Props: `review`, `myHelpful`, `canEdit`, `canReply`, `canReport`
- States: collapsed, expanded if body > 240 chars

### `RatingHistogramBar`
- Pure-CSS-style bars, accessible with aria-valuenow

## 6. Empty / Error / Loading

- **Empty:** "No reviews yet. Be the first to share what makes this server great." CTA: Write a review
- **Error:** retry banner above list
- **Loading:** 3 skeleton cards

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Reviews |
| CTA | Write a review |
| Empty | No reviews yet. Be the first. |
| Error | Could not load reviews |
| Block tooltip | Members can review after 14 days and 20 messages |
| Reply badge | Owner |

## 8. Motion

- Star tap: scale 0.9 -> 1.1 -> 1 in 220ms
- Card insert: slide-in 220ms
- Reduced motion: crossfade

## 9. Accessibility

- Stars announce "{N} of 5"
- Histogram bars include numeric value in label
- Compose field announces remaining char count every 50 chars
- Helpful button toggles with role=switch

## 10. Responsive

- Phone: single column
- Tablet/web: 2-column at 840+

## 11. Theming

- Stars use server accent if set; default `tertiary`
- Owner-reply background `surfaceContainer`
