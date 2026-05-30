# Task Management — UI/UX Design

## 1. Design Principles

- Inherit Flicko theme tokens; no new color introduction
- Status colors map to semantic tokens: todo=neutral, in_progress=info, blocked=warning, done=success, cancelled=disabled
- Density: compact rows (52pt) optimised for scanning
- Action-first: swipe-right marks done, swipe-left assigns
- Match existing chat fonts; do not introduce new typography

## 2. Information Architecture

- Entry points (3 max):
  1. Server side rail "Tasks"
  2. Channel header overflow -> "Channel tasks"
  3. Profile -> "My tasks" (cross-server inbox)
- Deep links:
  - `flicko://server/<sid>/tasks`
  - `flicko://server/<sid>/task/<short_id>`
  - `flicko://me/tasks`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Task List | Filtered tasks within server/channel | empty, loading, content, error |
| 2 | Task Detail | Read & edit one task | loading, content, archived, error |
| 3 | Task Compose | Create or edit | draft, validating, saving, error |
| 4 | Inbox | "My tasks" cross-server | empty, content, loading |
| 5 | Convert Sheet | From-message conversion | prefilled, error |

## 4. Wireframes (ASCII)

### Screen 1 — Task List

```
┌──────────────────────────────────────────────────────┐
│ ← Tasks · Server                              [⋮]    │
├──────────────────────────────────────────────────────┤
│ Filters:  [All] [Open] [Done] [Mine]                 │
│ Channel: [All ▾]  Label: [All ▾]  Sort: [Due ▾]      │
├──────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────┐ │
│ │ #142 ● in_progress  ⚠ urgent                     │ │
│ │ Triage Android crash on upload                   │ │
│ │ #bug · @priya · due Fri 5pm · 2 comments         │ │
│ ├──────────────────────────────────────────────────┤ │
│ │ #141 ○ todo                                      │ │
│ │ Write release notes for v2.4                     │ │
│ │ @alex · due tomorrow                             │ │
│ ├──────────────────────────────────────────────────┤ │
│ │ #140 ◑ blocked                                   │ │
│ │ Refresh icon assets                              │ │
│ │ #design · @sam · waiting on brand                │ │
│ └──────────────────────────────────────────────────┘ │
│                                              [+]    │
└──────────────────────────────────────────────────────┘
   ← swipe: assign        swipe →: mark done
```

### Screen 2 — Task Detail

```
┌──────────────────────────────────────────────────────┐
│ ← #142                                       [⋮]    │
├──────────────────────────────────────────────────────┤
│ Triage Android crash on upload                       │
│  Status:   [ in_progress ▾ ]                         │
│  Priority: ⚠ urgent                                  │
│  Due:      Fri Jun 13, 5:00 PM EDT                   │
│  Channel:  #bug-reports                              │
│  Labels:   [bug] [android]                           │
│  Assignees: ( P ) ( S ) +                             │
│  Linked:   from message in #bug-reports →           │
├──────────────────────────────────────────────────────┤
│ Description                                          │
│ ──────────────────────────────────────────────       │
│ Stack trace shows OutOfMemory in compress step.      │
│ Repro: pick image > 10MB.                            │
├──────────────────────────────────────────────────────┤
│ Activity                                             │
│  • @priya assigned (2h ago)                          │
│  • status: todo -> in_progress (1h ago)              │
│ Comments                                             │
│  @priya: have a draft fix, testing now (30m ago)     │
│ ┌──────────────────────────────────────────────────┐ │
│ │ Write a comment...                               │ │
│ └──────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### Screen 3 — Convert Message Sheet

```
┌──────────────────────────────────────────────────────┐
│ Convert to task                                ✕    │
├──────────────────────────────────────────────────────┤
│ From @member · #bug-reports · 5m ago                 │
│ "App crashes on Android 12 when uploading >10MB..."  │
│                                                      │
│ Title*                                               │
│ [ App crashes on Android 12 ...                ]     │
│ Assign to                                            │
│ [ + Add assignee ]                                   │
│ Due                                                  │
│ [ Pick date ▾ ]    Priority [ medium ▾ ]            │
│ Labels [ + ]                                         │
├──────────────────────────────────────────────────────┤
│                              [ Cancel ]  [ Create ]  │
└──────────────────────────────────────────────────────┘
```

### Screen 4 — Inbox

```
┌──────────────────────────────────────────────────────┐
│ ← My tasks                                           │
├──────────────────────────────────────────────────────┤
│ Overdue (2)                                          │
│  ⚠ #142 Triage Android crash · Server A · -2h        │
│  ⚠ #088 Update privacy policy · Server B · -1d       │
│ Today (1)                                            │
│  ● #143 Send digest · Server A · 5pm                 │
│ This week (4)                                        │
│  ○ #150 Sprint review prep · Server B · Fri          │
│  ○ #151 Migrate cron · Server A · Sat                │
│  ...                                                 │
│ No due (8)                                           │
└──────────────────────────────────────────────────────┘
```

### Slash Compose Inline

```
You: /task new
     ┌───────────────────────────────────────┐
     │ /task new <title> [@user] [due:Fri]   │
     │   /task assign #142 @user             │
     │   /task done   #142                   │
     │   /task list   mine                   │
     └───────────────────────────────────────┘
```

## 5. Component Specs

### `TaskCard`
- Props: `task: Task`, `onTap`, `onSwipeDone`, `onSwipeAssign`
- States: idle / pressed / swiping / submitting
- A11y: announces "Task one forty-two, in progress, due Friday five PM"

### `PriorityPill`
- Props: `priority`
- Visual: leading dot color + label; uses shape (none=blank, low=○, medium=●, high=▲, urgent=⚠)

### `DueChip`
- Color shifts: future=neutral, today=warning, overdue=error
- Format: "tomorrow 5pm" / "Fri 5pm" / "Jun 8" / "in 2h" / "-3h"

### `AssigneeStack`
- Up to 3 avatars + "+N"
- Tap opens picker; long-press shows full list

## 6. Empty / Error / Loading

- Empty (server): clipboard illustration + "No tasks yet" + CTA "+ New task"
- Empty (inbox): zen check + "All clear. Nice work."
- Error: inline banner; "Couldn't sync. Retry."
- Loading: 4 shimmer cards

## 7. Copy

| Surface | Copy |
|---------|------|
| Tab title | Tasks |
| FAB | New task |
| Empty title | No tasks yet |
| Empty body (server) | Pin work that matters here. |
| Empty body (inbox) | All clear. Nice work. |
| Convert title | Convert to task |
| Done toast | Marked #{n} done. |
| Reminder push | "#{n} due in 1 hour" |
| Slash help | "/task new <title> [@user] [due:Fri]" |

Voice: short, friendly, action-oriented.

## 8. Motion

- Page transitions: shared-axis Y 300ms
- Swipe: native dismiss feel; bounce-back on partial swipe
- Status pill flip: scale 0.95 -> 1.05 -> 1.0 with checkmark fade-in (180ms)
- Reduced motion: replace bounce with crossfade

## 9. Accessibility

- Screen reader: every card announces id, status, priority, due
- Color paired with shape for status (○ ● ◑ ✓ ✕)
- Tap targets >=44pt
- Keyboard: J/K to navigate list, Enter to open, X to mark done

## 10. Responsive

- Phone: single column
- Tablet: two-pane (list left, detail right)
- Web: three-pane (filters / list / detail)
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
- Honors server accent for primary CTA
- Status semantic tokens reused from existing `mobile/lib/core/theme/semantic_colors.dart`
