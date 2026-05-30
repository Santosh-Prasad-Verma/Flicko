# Reminders — UI/UX Design

## 1. Design Principles

- Conversational entry: type `/remind` -> inline preview chip resolves before send
- Notification action buttons: Done / Snooze 10m / Snooze 1h
- List view is text-first; visual chrome minimal
- Time parser is forgiving; suggestions appear when ambiguous

## 2. Information Architecture

- Entry points:
  1. Composer slash autocomplete `/remind`
  2. Profile -> "Reminders"
  3. Notification action button
- Deep link: `flicko://me/reminders` and `flicko://reminder/<id>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Composer slash | Set inline | preview, ambiguous, error |
| 2 | Reminder List | View/edit pending | empty, content, loading |
| 3 | Reminder Detail | Edit text/time | content, saving |

## 4. Wireframes (ASCII)

### Slash autocomplete inline

```
You: /remind|
     ┌────────────────────────────────────────────┐
     │ /remind  me <when> <text>                  │
     │ /remind  #channel <when> <text>            │
     │ /remind  @user <when> <text>               │
     │ /remind  list                              │
     └────────────────────────────────────────────┘

You: /remind me in 30m follow up with priya
     ┌────────────────────────────────────────────┐
     │ 🔔 Reminder · in 30 min · 5:42 PM EDT      │
     │ "follow up with priya"                     │
     │       [ Cancel ]   [ Set ]                 │
     └────────────────────────────────────────────┘
```

### Ambiguous parse

```
You: /remind me later about taxes
     ┌────────────────────────────────────────────┐
     │ I couldn't read "later". Try one of:        │
     │  [in 1 hour] [tomorrow 9am] [friday 9am]    │
     └────────────────────────────────────────────┘
```

### Reminder List

```
┌────────────────────────────────────────────────┐
│ ← Reminders                                    │
├────────────────────────────────────────────────┤
│ Pending (3)                                    │
│ ┌────────────────────────────────────────────┐ │
│ │ 🔔 in 30 min · self                        │ │
│ │ follow up with priya                       │ │
│ │ [Snooze 10m] [Cancel]                      │ │
│ ├────────────────────────────────────────────┤ │
│ │ 🔔 tomorrow 9:00 AM · #standup             │ │
│ │ "post your update" · weekdays              │ │
│ ├────────────────────────────────────────────┤ │
│ │ 🔔 Fri 5:00 PM · DM @priya                 │ │
│ │ "send doc"                                 │ │
│ └────────────────────────────────────────────┘ │
│ Recently fired (24h)                           │
│  ✓ took 5 min vitamins                         │
└────────────────────────────────────────────────┘
```

### Notification (push)

```
🔔 Flicko · now
follow up with priya
[ Done ]   [ +10m ]   [ +1h ]
```

## 5. Component Specs

### `ReminderChip`
- Inline in composer; renders parsed time and text
- States: parsing, ready, ambiguous (amber)

### `SnoozeMenu`
- Quick: 10m, 1h, tomorrow same time

### `RecurrencePresetPicker`
- Daily, Weekdays, Weekly on weekday, Monthly on Nth, Custom

## 6. Empty / Error / Loading

- Empty list: bell illustration; "No reminders set"
- Error: inline banner

## 7. Copy

| Surface | Copy |
|---------|------|
| Slash help title | Set a reminder |
| Empty state | No reminders set |
| Confirm chip | Reminder set for {time} |
| Snooze toast | Snoozed 10 minutes |
| Ambiguous | Couldn't read "{token}". Try one of these. |

## 8. Motion

- Chip scale 0.9 -> 1.0 (180ms)
- Snooze haptic light

## 9. Accessibility

- Slash help is screen-reader accessible
- Time announced as "five forty two PM"

## 10. Responsive

- Phone: native overlay
- Tablet/web: inline popover
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
