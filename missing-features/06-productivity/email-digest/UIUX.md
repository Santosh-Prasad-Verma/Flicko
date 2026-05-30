# Email Digest — UI/UX Design

## 1. Design Principles

- Email design uses brand-light palette but adapts to dark mode via `@media (prefers-color-scheme)`
- Above-the-fold: name + count of mentions; one-tap deep link to app
- Preview text optimized: "{n} mentions, {n} threads, {n} events"
- Footer: clear unsubscribe + preferences link
- Mobile-first email layout (single column 600px max)

## 2. Information Architecture

- Settings -> Notifications -> Email digest
- Email body sections in priority order

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Preferences | Configure cadence + servers | content, saving, error |
| 2 | Email Body | What lands in the inbox | empty, populated |
| 3 | Unsubscribe Confirmation | Web confirmation page | success, error |

## 4. Wireframes (ASCII)

### Preferences

```
┌────────────────────────────────────────────────┐
│ ← Email digest                                 │
├────────────────────────────────────────────────┤
│ Cadence                                        │
│  ◯ Off                                         │
│  ◯ Daily                                       │
│  ●  Weekly                                     │
│     Day [ Monday ▾ ]   Time [ 9:00 AM ▾ ]      │
│     Time zone   America/New_York               │
│                                                │
│ Include servers                                │
│  ☑ Acme Inc.                                  │
│  ☑ Side Project                                │
│  ☐ Big Noisy Community  (muted)                │
│  ☑ Friends                                     │
│                                                │
│ Preview my next digest [→]                     │
└────────────────────────────────────────────────┘
```

### Email Body (one-column, 600px)

```
┌──────────────────────────────────────────────┐
│  ╔═════════════════════════════════════════╗ │
│  ║  Flicko · Your weekly digest            ║ │
│  ║  Monday, Jun 1                           ║ │
│  ╚═════════════════════════════════════════╝ │
│                                              │
│  3 mentions   2 threads   1 event            │
│                                              │
│  ─── Mentions ─────────────────────────────  │
│                                              │
│  @priya · #engineering · 3d ago              │
│  "@you can you review the migration?"        │
│  [ Open in Flicko ]                          │
│  ────────────────────────                    │
│  @sam · #design · 5d ago                     │
│  "@you wdyt about the new icons?"            │
│  [ Open in Flicko ]                          │
│                                              │
│  ─── Threads you joined ───────────────────  │
│                                              │
│  Bug: image upload crashes  · 12 replies     │
│  Latest: "looks like an OOM"                 │
│  [ Read in Flicko ]                          │
│                                              │
│  ─── Events this week ─────────────────────  │
│                                              │
│  Friday Game Night · Fri 8 PM · You're going │
│  [ View event ]                              │
│                                              │
│  ─── Trending in Side Project ─────────────  │
│                                              │
│  "RFC: storage backend choice" · 38 replies  │
│  [ Read ]                                    │
│                                              │
│  ────────────────────────                    │
│  Sent because you opted in.                  │
│  Unsubscribe · Preferences                   │
└──────────────────────────────────────────────┘
```

### Unsubscribe Confirmation Page

```
┌──────────────────────────────────────────────┐
│  Flicko                                      │
│                                              │
│  You're unsubscribed.                        │
│  We won't send digests until you opt back in.│
│                                              │
│  [ Open Flicko ]   [ Re-enable ]             │
└──────────────────────────────────────────────┘
```

## 5. Component Specs

### `DigestSection`
- Header line + items list with [Open] CTA per item

### `CadenceRadioGroup`
- Three options + day/hour pickers when Weekly chosen

### `ServerCheckboxList`
- Lists user's joined servers with mute indicator

## 6. Empty / Error / Loading

- Empty preview: "No activity to summarize yet"
- Error sending: in-app banner

## 7. Copy

| Surface | Copy |
|---------|------|
| Heading | Your weekly digest |
| CTA button | Open in Flicko |
| Footer | Sent because you opted in. |
| Unsub | Unsubscribe |
| Confirmation | You're unsubscribed. |

## 8. Motion

Email is static; preferences screen uses standard transitions.

## 9. Accessibility

- Email: alt text on every image; semantic h1/h2
- Plain text version always sent
- Sufficient contrast in both light/dark email rendering

## 10. Responsive

- Email: 600px max single column
- Preferences: phone full screen; tablet/web side panel
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Email: light + dark via prefers-color-scheme
- App settings: standard themes
