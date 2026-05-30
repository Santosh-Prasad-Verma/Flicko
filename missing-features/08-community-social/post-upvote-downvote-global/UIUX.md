# Post Upvote/Downvote Global — UI/UX Design

## 1. Design Principles

- Vote arrows live next to message timestamp, not below the bubble
- Animation is celebratory but quiet, never blocking
- Arrows hidden entirely on channels with voting disabled, not just greyed
- Reduce visual noise on small phones; arrows fade in on tap-and-hold of message
- Accessibility: 44pt tap target, separate Semantics for up and down

## 2. Information Architecture

- Entry points: every message bubble in vote-enabled channels, every forum-post header
- Settings: per-channel toggle in channel settings under "Permissions and Visibility"
- Mod audit: server settings -> Moderation -> Vote Audit

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Message bubble with arrows | cast/retract vote | none, up, down, locked, disabled |
| 2 | Forum post header arrows | same | same |
| 3 | Channel settings -> Voting | enable/disable per channel | on, off, suspended |
| 4 | Mod vote audit | review last 7d of votes | content, empty, filtered |

## 4. Wireframes (ASCII)

### Message bubble inline arrows

```
+--- chat row ----------------------------------+
| [@] @riku    11:42                            |
|  Got the calendar fix working, see PR.        |
|  +-- arrows -----+                            |
|  |  ^ 12  v      |   reply  thread  more      |
|  +----------------+                            |
+------------------------------------------------+

selected up:
|  +----------------+
|  |  *^ 13* v      |
|  +----------------+

selected down (red tint):
|  +----------------+
|  |  ^ 12 *v 1*    |
|  +----------------+

disabled (account <24h):
|  +-----------------------+
|  |  ^ 12  v   (locked)   |
|  +-----------------------+
```

### Channel settings — Voting

```
+--------------------------------------------------+
| < Channel settings - #help                       |
+--------------------------------------------------+
| Permissions    Visibility    *Voting*    Webhooks|
+--------------------------------------------------+
|                                                  |
|  Voting on messages          [ on  /  off ]      |
|  Allow downvotes             [ on  /  off ]      |
|  Min account age (hours)     [ 24 ]              |
|                                                  |
|  Existing votes are preserved when disabled.     |
|                                                  |
+--------------------------------------------------+
```

### Mod vote audit

```
+--------------------------------------------------+
| < Vote audit  -  Last 7 days                     |
+--------------------------------------------------+
| filter: [ all | suspect | by user | by post ]    |
+--------------------------------------------------+
| Time     User        Target        v  suspect    |
| 11:42    @user_a     msg-3jk...     +1  no       |
| 11:43    @user_b     msg-3jk...     +1  no       |
| 11:43    @new_x      msg-3jk...     -1  YES      |
| 11:44    @new_y      msg-3jk...     -1  YES      |
|                                                  |
|  3 of 14 votes flagged as suspect                |
|  [ recompute scores ]                            |
+--------------------------------------------------+
```

## 5. Component Specs

### `VoteArrows`
- Props: `score`, `myVote`, `disabled`, `disableDownvote`, `onCast`
- States: idle, pressed, locked
- Token usage: `colorScheme.primary` for upvote selected; `colorScheme.error` for downvote selected; `outlineVariant` for default

### `VoteCount`
- Animates count change with TweenAnimationBuilder, 200ms
- Renders `--` when score hidden by privacy mode

## 6. Empty / Error / Loading

- **Empty:** never; arrows always show 0 unless disabled
- **Error:** silent, revert optimistic change, snackbar "Could not record your vote"
- **Loading:** none; optimistic UI

## 7. Copy

| Surface | Copy |
|---------|------|
| Locked tooltip | Available after 24 hours on Flicko |
| Disabled channel toast | Voting is off in this channel |
| Rate limit | Slow down for a sec |
| Self-vote tooltip | You cannot vote on your own posts |

## 8. Motion

- Tap arrow: scale 0.9 -> 1.1 -> 1.0 in 220ms
- Count change: digit roll 200ms
- Reduced motion: replace scale with single-frame color flip

## 9. Accessibility

- Up arrow Semantics label "Upvote, current score {N}, your vote {state}"
- Down arrow Semantics label "Downvote, current score {N}, your vote {state}"
- Activation announces "Upvoted" / "Vote retracted" via live region
- Color contrast on selected arrows: 4.5:1 against bubble background

## 10. Responsive

- Phone: arrows inline, count hidden if <0 to save space
- Tablet/web: arrows always visible with count
- Desktop keyboard: U for up, D for down when message focused

## 11. Theming

- Selected up uses `primary` token; selected down uses `error` token
- AMOLED: outline-only arrows, fill on selection
