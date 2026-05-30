# Scheduled Messages — UI/UX Design

## 1. Design Principles

- Lives inside the existing composer; one extra icon, never a separate flow
- Always show the absolute time and the relative time ("in 16 hours")
- Recurring intent is opt-in; default is one-time
- Error state never blocks composer; pending list reachable in 2 taps

## 2. Information Architecture

- Entry points:
  1. Composer clock icon (next to attachments / emoji)
  2. Profile -> "Scheduled messages"
  3. Long-press any sent message -> "Schedule a copy" (v1.1, not v1)
- Deep link: `flicko://me/scheduled`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Composer + clock | Compose with optional schedule | idle, scheduling |
| 2 | Schedule Sheet | Pick time / recurrence | quick-pick, custom, error |
| 3 | Scheduled List | View / edit pending | empty, content, loading, error |
| 4 | Schedule Detail | Edit body and time | content, saving, error |

## 4. Wireframes (ASCII)

### Screen 1 — Composer with clock

```
┌────────────────────────────────────────────────┐
│ #announcements                                 │
│ ─────────────────────────────────────────────  │
│ ## Weekly Update                               │
│ Hello team,...                                 │
│                                                │
│ [📎] [🙂] [🕒]                          [➤]   │
└────────────────────────────────────────────────┘
                         ▲
                tapping 🕒 opens Schedule Sheet
```

### Screen 2 — Schedule Sheet

```
┌────────────────────────────────────────────────┐
│ Send later                              ✕      │
├────────────────────────────────────────────────┤
│ Quick                                          │
│  [ Tomorrow 9am ]   [ Mon 9am ]   [ Tonight ]  │
│                                                │
│ Custom                                          │
│ Date  [ Jun 1, 2026 ]   Time [ 9:00 AM ]       │
│ Time zone [ America/New_York ▾ ]              │
│                                                │
│ Repeat                                          │
│  ◯ Once                                         │
│  ◯ Daily                                        │
│  ◯ Weekdays                                     │
│  ●  Weekly on [ Sun ]                           │
│  Ends after [ 12 ▾ ] occurrences               │
├────────────────────────────────────────────────┤
│                       [ Cancel ]  [ Schedule ] │
└────────────────────────────────────────────────┘
```

### Screen 3 — Scheduled List

```
┌────────────────────────────────────────────────┐
│ ← Scheduled messages                           │
├────────────────────────────────────────────────┤
│ Pending (3)                                    │
│ ┌────────────────────────────────────────────┐ │
│ │ #announcements  Sun 9:00 AM (in 16h)       │ │
│ │ ## Weekly Update Hello team...             │ │
│ │ [ Edit ]  [ Send now ]  [ Cancel ]         │ │
│ ├────────────────────────────────────────────┤ │
│ │ DM @priya  Mon 7:30 AM (recurring weekly)  │ │
│ │ Good morning! Quick checklist...           │ │
│ ├────────────────────────────────────────────┤ │
│ │ #standup  Daily 9:00 AM (recurring)        │ │
│ │ /standup template                          │ │
│ └────────────────────────────────────────────┘ │
│                                                │
│ Recently sent (last 7d)                        │
│  ✓ #announcements last Sunday                  │
│  ✓ DM @priya yesterday                         │
└────────────────────────────────────────────────┘
```

### Screen 4 — Schedule Detail (Edit)

```
┌────────────────────────────────────────────────┐
│ ✕  Edit scheduled message                Save  │
├────────────────────────────────────────────────┤
│ Channel: #announcements                        │
│ Fires:   Sun Jun 1, 9:00 AM EDT  [Change ▾]   │
│ Repeats: Once                                   │
│                                                 │
│ Body                                            │
│ ┌────────────────────────────────────────────┐ │
│ │ ## Weekly Update                           │ │
│ │ Hello team,                                │ │
│ │ ...                                        │ │
│ └────────────────────────────────────────────┘ │
│ Attachments [ + ]                               │
│                                                 │
│ Danger zone                                     │
│ [ Cancel schedule ]                             │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `ScheduleChip`
- Renders inline above composer when a schedule attached
- Tap opens sheet to change time
- Removes via X on chip

### `QuickTimePill`
- Tomorrow 9am, Monday 9am, Tonight 8pm (uses user tz)
- Disabled if computed time is in the past

## 6. Empty / Error / Loading

- Empty list: clock illustration + "No scheduled messages"
- Error: banner inside list; "Couldn't reach server. Retry."
- Loading: skeleton 3 rows

## 7. Copy

| Surface | Copy |
|---------|------|
| Sheet title | Send later |
| Confirm button | Schedule |
| Pending list title | Scheduled messages |
| Empty state | No scheduled messages |
| Cancel confirm | Cancel this scheduled message? |
| Failed-to-send banner | We couldn't send this. Tap to retry or edit. |
| Quota banner | You're at 50 of 50. Cancel one to schedule more. |

## 8. Motion

- Sheet slide-up 250ms
- Chip enters with scale 0.9 -> 1.0 (180ms)
- Reduced motion: crossfade

## 9. Accessibility

- Sheet announces selected time on change
- Quick pills include relative time in label
- Tap targets >=44pt
- Keyboard date picker supports type-in

## 10. Responsive

- Phone: bottom sheet
- Tablet: dialog 480px wide
- Web: popover anchored to clock icon
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
- Honors server accent for primary "Schedule" CTA
