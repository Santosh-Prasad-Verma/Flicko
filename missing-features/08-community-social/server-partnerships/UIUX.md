# Server Partnerships — UI/UX Design

## 1. Design Principles

- Treat partnerships as a relationship, not a list of links
- Surface partners on the public-facing About tab; manage in settings
- Make analytics instantly readable (numbers, no charts mandatory)
- Be careful with social pressure: do not gamify partner counts

## 2. Information Architecture

- Entry points: Server settings -> Partnerships, Server About tab (member view)
- Parent: server settings; About tab for read view
- Deep link: `flicko://server/<id>/settings/partnerships`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Partners list (settings) | Manage all | empty, content |
| 2 | About tab partners section | Member view | empty hidden, content |
| 3 | Propose dialog | Search + message | drafting, submitting, error |
| 4 | Inbox | Accept/decline | empty, content |
| 5 | Analytics | Metrics per partnership | empty, content |

## 4. Wireframes (ASCII)

### Partners list (settings)

```
+--------------------------------------------------+
| <  Aurora Devs - Partnerships                    |
+--------------------------------------------------+
|  Active (4 / 25)                  [+ Propose ]   |
|                                                  |
|  +-- card -----------------------------+         |
|  | [logo]  Rust Nerds                  |         |
|  | active since Mar 12                  |         |
|  | clicks 442  joins 38  retained 22    |         |
|  | [ Manage ]                           |         |
|  +--------------------------------------+        |
|                                                  |
|  +-- card -----------------------------+         |
|  | [logo]  Birdwatch                   |         |
|  | active since Apr 1                   |         |
|  | clicks 121  joins 11  retained 7     |         |
|  +--------------------------------------+        |
|                                                  |
|  Pending (1)                                     |
|                                                  |
|  +-- card -----------------------------+         |
|  | [logo]  Calendar Pals - waiting...  |         |
|  +--------------------------------------+        |
+--------------------------------------------------+
```

### Propose dialog

```
+--------------------------------------------------+
|  Propose a partnership                           |
+--------------------------------------------------+
|  Search server                                    |
|  ____________________________________            |
|  pick a server, paste invite, or browse           |
|                                                   |
|  Message (optional)                               |
|  +---------------------------------------------+ |
|  | Hi! Big fan of your design crit channel.    | |
|  | Would love to swap members.                 | |
|  +---------------------------------------------+ |
|                                                   |
|  This proposal expires in 14 days.                |
|                                                   |
|                              [ Send proposal ]    |
+--------------------------------------------------+
```

### About tab (member view)

```
+--------------------------------------------------+
|  Partners                                        |
+--------------------------------------------------+
|  +- Rust Nerds -+   +- Birdwatch -+   +- Cal -+  |
|  |   [logo]     |   |   [logo]    |   |[logo] |  |
|  |  3.2k members|   |  1.1k       |   | 814   |  |
|  |  [ Visit ]   |   |  [ Visit ]  |   |[Visit]|  |
|  +--------------+   +-------------+   +-------+  |
+--------------------------------------------------+
```

### Inbox

```
+--------------------------------------------------+
| <  Partnership inbox                             |
+--------------------------------------------------+
|  +-- card -----------------------------+         |
|  | [logo] Aurora Devs proposes a       |         |
|  | partnership                          |         |
|  | "Hi! Big fan of your design crit..." |         |
|  | [ Accept ]   [ Decline ]   [ View ]  |         |
|  +--------------------------------------+        |
+--------------------------------------------------+
```

## 5. Component Specs

### `PartnershipCard`
- Props: partner server, status, metrics
- Long-press: Manage / Terminate

### `PartnerBadgeChip`
- 28pt rounded chip used in member About tab

## 6. Empty / Error / Loading

- **Empty list:** "No partnerships yet. Propose one to get started."
- **Empty inbox:** "All caught up."
- **Error:** banner, retry
- **Loading:** 3 skeleton cards

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Partnerships |
| CTA | Propose |
| Empty | No partnerships yet. |
| Pending | Waiting on {partner} |
| Cooldown banner | This pair is in a 14-day cooldown |
| Decline reason placeholder | Optional reason |

## 8. Motion

- Card insert: slide-in 220ms
- Accept: badge bloom + check 280ms
- Reduced motion: crossfade

## 9. Accessibility

- Card announces partner name, status, metric headlines
- Action buttons clearly labeled with target server name
- Focus order: list -> first card -> action

## 10. Responsive

- Phone: single column cards
- Tablet/web: 2-column cards at 720+

## 11. Theming

- Partner logos shown as round avatars; respect server accent ring
- Cooldown chip warmer-grey; active chip uses `tertiary`
