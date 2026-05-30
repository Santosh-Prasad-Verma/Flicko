# Read Receipts Control — UI/UX Design

## 1. Design Principles

- Default-off behavior is a feature, not a bug. The first message you read after the rollout shows a one-time tooltip explaining what changed.
- Toggles are co-located with their scope: DM settings for DMs, friend profile for friends, server settings for servers.
- Reciprocity is explained in plain language right next to the toggle.

## 2. Information Architecture

Where this feature lives:
- Entry points (4): DM settings; friend profile → privacy; server settings → privacy; global settings → privacy.
- Deep links: `flicko://settings/privacy/receipts`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Receipt toggle tile | Single tile reused everywhere | off, on, mixed |
| 2 | First-time tooltip | Explain default-off | content |
| 3 | Settings → privacy → receipts | Master view | content |
| 4 | DM settings privacy block | Per-DM toggle | content |
| 5 | Friend profile privacy block | Per-friend toggle | content |
| 6 | Server settings privacy block | Per-server toggle | content |

## 4. Wireframes (ASCII)

### Receipt toggle tile (DM settings example)
```
┌────────────────────────────────────┐
│  Read receipts            [ on ●●] │
│  You and Alex will both see when   │
│  the other has read messages.      │
└────────────────────────────────────┘
```

When global is on but a DM is off, tile shows:
```
┌────────────────────────────────────┐
│  Read receipts            [ off  ] │
│  Off here, even though you have    │
│  receipts on by default.           │
└────────────────────────────────────┘
```

### First-time tooltip
```
┌────────────────────────────────────┐
│  We turned read receipts off       │
│  by default                        │
│                                    │
│  You can turn them on per chat or  │
│  globally in Settings → Privacy.   │
│                                    │
│             [ Got it ]             │
└────────────────────────────────────┘
```

### Settings → privacy → receipts
```
┌────────────────────────────────────┐
│  Read receipts                     │
├────────────────────────────────────┤
│  Default                           │
│  ○ off   ● on                      │
│                                    │
│  Reciprocity                       │
│  You will only see receipts from   │
│  people who also send you theirs.  │
│                                    │
│  Per-friend overrides     ›        │
│  Per-server overrides     ›        │
└────────────────────────────────────┘
```

## 5. Component Specs

### `ReceiptToggleTile`
- Props: `scope: ReceiptScope`, `value: ReceiptPolicy`, `onChange`.
- Subtitle dynamically computed: explains current effective state.
- Long press: explains reciprocity.

### `FirstTimeReceiptTooltip`
- One-time per device, dismissable.

## 6. Empty / Error / Loading

- **Empty (no overrides):** "All scopes use your default." with a CTA to set defaults.

## 7. Copy

| Surface | Copy |
|---------|------|
| Toggle title | Read receipts |
| Toggle off subtitle | You won't send or see read receipts here. |
| Toggle on subtitle | You and {name} will both see when each other has read messages. |
| Reciprocity helper | You only see receipts from people who also send you theirs. |
| Tooltip body | We turned read receipts off by default. You can turn them on per chat or globally. |

Voice: clear, factual, neutral. No "stalker"/"creep" language.

## 8. Motion

- Toggle: 150ms switch with subtle haptic.
- Tooltip: fade-in 200ms.

## 9. Accessibility

- Toggle uses native Switch with Semantics.
- Tooltip is dismissable via screen reader.
- Tap targets ≥44pt.

## 10. Responsive

- Phone: settings list view.
- Tablet/web: master/detail.

## 11. Theming

- Standard tokens; no special chrome.
