# Local Timezones — UI/UX Design

## 1. Design Principles

- **Always relative + always absolute available:** never make users guess "how long ago".
- **Mention TZ when ambiguous:** if a user lives in JST and we show 19:43, append "JST" only when context is cross-zone (e.g. inviting an LA user).
- **Human-friendly relative:** "Just now", "5 min ago", "Yesterday", "Tuesday", "May 14".
- **Calm absolute:** "May 29, 14:00 JST" — no seconds; no AM/PM if locale uses 24h.
- **Tooltip / long-press for details:** keeps the row uncluttered.

## 2. Information Architecture

- TZ setting: `Settings → Language & Region → Timezone`
- All timestamps in app are powered by `Timestamp` widget — single source.
- Deep link: `flicko://settings/timezone`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | TimezoneSettingsScreen | pick / search TZ | content, search, applied, error |
| 2 | Timestamp (component) | render any timestamp | now, recent, yesterday, older, future, invalid |
| 3 | EventTimeBlock (component) | dual-TZ event renderer | viewer-tz, creator-tz, both |
| 4 | TimezoneChangeBanner | prompt when device TZ differs | shown, dismissed |

## 4. Wireframes (ASCII)

### Screen 1 — TimezoneSettingsScreen

```
┌────────────────────────────────────────┐
│ ← Timezone                             │
├────────────────────────────────────────┤
│ ┌────────────────────────────────────┐ │
│ │ 🔍  Search by city                 │ │
│ └────────────────────────────────────┘ │
│                                        │
│ Suggested                              │
│ ┌────────────────────────────────────┐ │
│ │ 📍 Asia/Tokyo (UTC+09:00) device ✓ │ │
│ │ 🌐 UTC (UTC+00:00)                 │ │
│ └────────────────────────────────────┘ │
│                                        │
│ All zones                              │
│ ┌────────────────────────────────────┐ │
│ │ Africa/Cairo       UTC+02:00       │ │
│ │ America/New_York   UTC−05:00       │ │
│ │ Asia/Kolkata       UTC+05:30       │ │
│ │ Pacific/Chatham    UTC+12:45       │ │
│ │ ...                                │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ☑ Use device timezone                  │
│ ☐ Always ask when device TZ changes    │
└────────────────────────────────────────┘
```

### Screen 2 — Message bubble Timestamp

```
┌─────────────────────────────────────┐
│ 👤 Mohammed                         │
│ Hello, did you finish the doc?      │
│                          5 min ago  │   ← long-press for absolute
└─────────────────────────────────────┘

  long-press →

┌─────────────────────────────────────┐
│ Sent 14:00 JST · May 29, 2026       │
│ UTC: 05:00 May 29                   │
└─────────────────────────────────────┘
```

### Screen 3 — Scheduled event in chat

```
┌─────────────────────────────────────────┐
│ 📅 Town Hall Q&A                        │
│                                         │
│ Tomorrow · 7:00 AM JST                  │
│ Creator's time: 23:00 BST today         │
│                                         │
│ [ Add to calendar ]   [ RSVP ]          │
└─────────────────────────────────────────┘
```

### Screen 4 — Timezone change banner

```
┌──────────────────────────────────────────┐
│ ⓘ You appear to be in Berlin             │
│ Show times in Europe/Berlin?             │
│ [ Yes, switch ]  [ Keep Tokyo ]  [ ✕ ]   │
└──────────────────────────────────────────┘
```

## 5. Component Specs

### `Timestamp` widget
- Props: `DateTime utc`, `TimestampStyle style = relative`, `bool includeTz = false`
- States:
  - `< 60s ago` → "Just now"
  - `< 1h ago` → "{n} min ago"
  - `< 24h ago` → "{n} hr ago"
  - `< 7d ago` → "{weekday}" or "Yesterday"
  - else → "{Mon} {d}" or full date if > 1y
  - future: "in {n} hr/day", "{Mon} {d}"
- On long-press / hover: tooltip with full absolute + UTC and zone abbrev
- Accessibility: Semantics label = full absolute reading

### `EventTimeBlock`
- Props: `DateTime utc`, `String creatorTz`, `bool showCreatorTz = true`
- Shows two lines:
  1. Viewer TZ (large)
  2. Creator TZ (small, italic)
- If viewer TZ == creator TZ, hides line 2.

### `TimezoneTile`
- Props: `String iana`, `int offsetMinutes`, `bool selected`, `String? badge`
- Layout: `[city]  [offset]   [badge?]   [✓]`

### `TimezoneChangeBanner`
- Triggered when device TZ differs from profile TZ for more than 1h sustained.
- Persistent until user picks an option.
- Settings toggle to silence.

## 6. Empty / Error / Loading

- **Empty:** N/A; everything has a timestamp.
- **Error (invalid TZ):** fall back to UTC silently; rare.
- **Loading:** never delay timestamp render — use cached profile TZ; if missing, render UTC and update on resolve.

## 7. Copy

| Surface | Copy (en source) |
|---------|------------------|
| Settings title | Timezone |
| Settings hint | Choose how times are shown across Flicko. |
| Search placeholder | Search by city |
| "Use device timezone" toggle | Use device timezone |
| Banner question | You appear to be in {city}. Show times in {tz}? |
| Banner CTA | Yes, switch |
| Banner alt CTA | Keep {current_city} |
| Just now | Just now |
| Minutes ago | {n} min ago |
| Hours ago | {n} hr ago |
| Yesterday | Yesterday |
| Tooltip prefix | Sent |
| UTC line | UTC: {time} |
| Creator's time | Creator's time: {time} {tz} |

Voice: friendly, concise, second-person.

## 8. Motion

- Settings → Timezone change: timestamps crossfade in 200ms (sometimes hundreds re-render; keep smooth).
- Banner appearance: slide-down 200ms; dismiss fade.
- Reduced-motion: instant.

## 9. Accessibility

- Every `Timestamp` exposes a Semantics label combining relative + absolute (e.g. "5 minutes ago, 14:00 Japan Standard Time, May 29 2026").
- Tooltip available via long-press on mobile, hover on web.
- Color contrast not affected (text-only).
- VoiceOver / TalkBack reads zone abbreviations correctly (verified in QA matrix).

## 10. Responsive

- Phone: same as default.
- Tablet/web: hover instead of long-press for absolute.
- Foldable: identical to phone.

## 11. Theming

- Inherits text colors. No special tokens.
- Stale or invalid timestamps colored `colorScheme.tertiary` for visibility.

## 12. Cross-Zone Event Rendering

For events scheduled across timezones, the rule:
- Headline = viewer's TZ
- Subtext = creator's TZ (italic, small)
- If viewer == creator: hide subtext to reduce noise
- DST shifts: if event is months away, show actual converted local time *as it will be on that future date* (correct via tzdata)
- "Add to calendar" exports `.ics` with `TZID=<viewer.tz>` so calendar apps don't double-translate

## 13. Pseudo-Zone (dev only)

- Toggle in dev menu: `Settings → Developer → Pseudo TZ → Etc/GMT-13`
- Forces every Timestamp to render in that zone, exposes any code path that hardcoded UTC or a stale tz.
- Banner: "Pseudo timezone: Etc/GMT-13 — for testing only"
