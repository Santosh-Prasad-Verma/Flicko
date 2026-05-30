# Calendar & Events — UI/UX Design

## 1. Design Principles

- Match Flicko's existing dark/light tokens (`mobile/lib/core/theme/`)
- Reuse `AppCard`, `AppPill`, `AppBottomSheet`, `AppFab`
- Motion: shared-axis Y for screen transitions; respect `reduced-motion`
- Every interactive element has Semantics label and >=44pt tap target
- Typography: titles `textTheme.titleMedium`, body `bodyMedium`, time stamps `labelLarge`

## 2. Information Architecture

- Entry points:
  1. Server side rail "Calendar" tab (icon: `calendar_today`)
  2. Channel header overflow -> "Channel events" (filtered list)
  3. Push notification deep link `flicko://calendar/event/<id>`
- Parent navigation: server scope (one calendar per server, optional channel filter)
- Deep links:
  - `flicko://server/<sid>/calendar`
  - `flicko://server/<sid>/calendar/event/<eid>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Calendar Grid | Month / week / agenda view | empty, loading, content, error |
| 2 | Event Detail | Read full info, RSVP, share | loading, content, cancelled, error |
| 3 | Event Compose | Create or edit event | draft, validating, saving, error |
| 4 | Recurrence Picker | Pick repeat pattern | none, simple, advanced |
| 5 | RSVP Sheet | Yes/No/Maybe + optional note | idle, submitting, error |

## 4. Wireframes (ASCII)

### Screen 1 — Calendar Grid (Month view)

```
┌───────────────────────────────────────────────────┐
│ ←  Server Name  ·  Calendar           [Month ▾] ⋮ │
├───────────────────────────────────────────────────┤
│      Jun 2026                          ◀  TODAY ▶ │
├───────────────────────────────────────────────────┤
│  Mo   Tu   We   Th   Fr   Sa   Su                 │
│  ──   ──   ──   ──   ──   ──   ──                 │
│   1    2    3    4   ●5    6    7                 │
│        ◌                  ●●                       │
│   8    9   10   11  ●12   13   14                 │
│                           ●                        │
│  15   16   17   18  ●19   20   21                 │
│                           ●                        │
│  22   23   24   25  ●26   27   28                 │
│                           ●                        │
│  29   30                                           │
├───────────────────────────────────────────────────┤
│ Upcoming                                           │
│ ┌───────────────────────────────────────────────┐ │
│ │ FRI 8:00 PM   Friday Game Night               │ │
│ │ #lounge-voice · 12 going · 3 maybe   [Going▾] │ │
│ ├───────────────────────────────────────────────┤ │
│ │ SAT 11:00 AM  Sprint Demo                     │ │
│ │ #standup · 4 going                  [RSVP ▾] │ │
│ └───────────────────────────────────────────────┘ │
│                                            ●  +   │
└───────────────────────────────────────────────────┘
  Legend: ● = event(s) on day, ◌ = today, ●● = >1
```

### Screen 2 — Event Detail

```
┌───────────────────────────────────────────────────┐
│ ←                                          ⋮      │
├───────────────────────────────────────────────────┤
│ ┌───────────────────────────────────────────────┐ │
│ │            (cover image 1200x630)             │ │
│ └───────────────────────────────────────────────┘ │
│ Friday Game Night                                  │
│ Friday, Jun 5  ·  8:00 PM – 10:00 PM EDT          │
│ Repeats weekly · 12 occurrences                    │
│ #lounge-voice  ·  Hosted by @mod_alex              │
├───────────────────────────────────────────────────┤
│ Bring your own chips. We'll pick a co-op tonight.  │
├───────────────────────────────────────────────────┤
│  ✓ Going (12)    ? Maybe (3)    ✗ Not going (1)   │
│ ┌───────────────────────────────────────────────┐ │
│ │ [   Going   ] [  Maybe  ] [ Can't make it ]   │ │
│ └───────────────────────────────────────────────┘ │
│ Reminders:  24h ·  1h ·  10m   [Customize]        │
├───────────────────────────────────────────────────┤
│ Attendees                                          │
│  • @user_a   ✓                                     │
│  • @user_b   ✓                                     │
│  • @user_c   ?                                     │
│  ... 12 more                                       │
├───────────────────────────────────────────────────┤
│ [ Subscribe in calendar ]  [ Share ]               │
└───────────────────────────────────────────────────┘
```

### Screen 3 — Event Compose

```
┌───────────────────────────────────────────────────┐
│ ✕  New event                              Save    │
├───────────────────────────────────────────────────┤
│ Title*                                             │
│ ┌───────────────────────────────────────────────┐ │
│ │ Friday Game Night                             │ │
│ └───────────────────────────────────────────────┘ │
│ Description                                        │
│ ┌───────────────────────────────────────────────┐ │
│ │ Bring your own chips...                       │ │
│ └───────────────────────────────────────────────┘ │
│ Starts                          Ends               │
│ [ Jun 5, 8:00 PM ]              [ Jun 5, 10:00 PM]│
│ Time zone   [ America/New_York ▾ ]                │
│                                                    │
│ Repeats     [ Weekly on Friday ▾ ]   ┌────┐       │
│                                       │Edit│       │
│                                       └────┘       │
│ Channel     [ #lounge-voice ▾ ]                   │
│ Capacity    [ 30 ▾ ] (optional)                   │
│ Reminders   ☑ 24h  ☑ 1h  ☑ 10m  + add             │
│ Cover image [ Upload / Pick template ]            │
└───────────────────────────────────────────────────┘
```

### Screen 4 — Recurrence Picker (Advanced)

```
┌───────────────────────────────────────────────────┐
│ ✕  Repeat                                  Done   │
├───────────────────────────────────────────────────┤
│  ◯ Does not repeat                                 │
│  ◯ Daily                                           │
│  ●  Weekly                                         │
│       Every [ 1 ▾ ] week(s) on:                   │
│       [M][T][W][T][F][S][S]                       │
│  ◯ Monthly                                         │
│       ◯ on the 5th                                 │
│       ◯ on the first Friday                       │
│  ◯ Custom (RRULE)                                  │
│                                                    │
│  Ends                                              │
│  ◯ Never                                           │
│  ●  After [ 12 ] occurrences                      │
│  ◯ On [ Aug 28, 2026 ]                            │
└───────────────────────────────────────────────────┘
```

## 5. Component Specs

### `MonthGrid`
- Props: `month: DateTime`, `events: List<EventOcc>`, `onTapDay`, `onTapEvent`
- States: idle / loading shimmer / empty / content
- Renders day cells with up to 3 dot markers; "+N" pill for overflow
- Tokens: `colorScheme.primary` for today ring, `secondary` for has-events

### `RsvpPill`
- Props: `state: RsvpState`, `onChange`, `disabled`
- States: idle / pressed / disabled / submitting
- A11y: announces "Going. Tap to change RSVP."

### `RecurrencePicker`
- Composes radio rows + day chips + count stepper
- Validates: at least one weekday selected; END pattern provided

## 6. Empty / Error / Loading

- **Empty (no events):** illustration of a wall calendar; copy "No upcoming events"; CTA "+ Schedule one" if user is mod.
- **Error (network):** inline banner under header; "Couldn't load. Retry."
- **Loading:** skeleton: 6 day rows shimmer + 3 agenda card skeletons

## 7. Copy

| Surface | Copy |
|---------|------|
| Tab title | Calendar |
| FAB | New event |
| Empty state title | No upcoming events |
| Empty state body | When mods schedule something, you'll see it here. |
| RSVP confirmation | You're going. We'll remind you 10 minutes before. |
| Cancel confirm | Cancel this event? Attendees will be notified. |
| Reminder push T-10m | "{title}" starts in 10 minutes. |
| ICS share sheet | Add "{title}" to your phone calendar |

Voice: friendly, second-person, no jargon.

## 8. Motion

- Page transitions: shared-axis Y, 300ms
- Day selection: scale 1.0 -> 1.04 -> 1.0, 200ms
- RSVP pill state change: color crossfade 150ms; confetti burst (200ms) only on first "yes" of an event
- Reduced motion: replace burst with checkmark fade

## 9. Accessibility

- Screen reader announces day cells as "Friday June 5, 2 events"
- Color contrast: dot markers paired with shape variation (circle vs. square) for color-blind users
- Keyboard: Tab through grid, arrow keys move day, Space opens day; Enter on card opens detail
- Reduced motion: crossfade replaces translate transitions
- Focus ring: 2px `colorScheme.primary` outline

## 10. Responsive

- Phone: month view only by default; agenda below
- Foldable: side-by-side month + agenda
- Tablet/web: month grid left, day detail right
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED variants
- Honors server accent color when `09-customization/accent-colors` ships; today ring uses accent
- Cover images darken 30% in dark theme to keep titles legible
