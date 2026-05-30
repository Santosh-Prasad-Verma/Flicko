# Channel Notes — UI/UX Design

## 1. Design Principles

- One tap from channel header; never hidden behind a menu
- Lighter than the docs editor: minimal toolbar, no comments, no version UI
- Auto-save indicator stays subtle (small Synced ✓ dot)
- Empty state encourages low-stakes first write

## 2. Information Architecture

- Entry points:
  1. Channel header "Notes" pin
  2. Channel slash `/notes` opens
  3. Deep link `flicko://channel/<cid>/note`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Note Screen | Read/edit single note | empty, editing, read-only, error |

## 4. Wireframes (ASCII)

### Note Screen

```
┌────────────────────────────────────────────────┐
│ ←  #lounge · Notes               Synced ✓ · ⋮ │
│ Last edited by @priya · 2m ago                 │
├────────────────────────────────────────────────┤
│ # Lounge FAQ                                   │
│                                                │
│ ## Rules                                       │
│  - Be kind                                     │
│  - No spam                                     │
│                                                │
│ ## Voice channel etiquette                     │
│  - Push to talk during raids                   │
│                                                │
│ ## Resources                                   │
│  - https://wiki...                             │
│                                                │
├────────────────────────────────────────────────┤
│  [B] [I] [H1] [H2] [•] [1.] [☐] [@] [{ }] [↶] │
└────────────────────────────────────────────────┘
```

### Empty State

```
┌────────────────────────────────────────────────┐
│ ←  #lounge · Notes                             │
├────────────────────────────────────────────────┤
│                                                │
│        No notes yet.                           │
│        Drop a checklist, a FAQ, anything       │
│        the channel should keep handy.          │
│                                                │
│        [ Start writing ]                       │
│                                                │
└────────────────────────────────────────────────┘
```

### Read-only banner (no write perm)

```
┌────────────────────────────────────────────────┐
│ View only — ask a mod for edit access.         │
└────────────────────────────────────────────────┘
```

### Convert prompt (size > 60 KB)

```
┌────────────────────────────────────────────────┐
│ This note's getting long. Convert to a Doc?    │
│                              [ Not now ] [ OK ]│
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `NoteHeader`
- Channel name, last-edited info, sync state
- Overflow: clear, share, convert to doc

### `LiteToolbar`
- Subset of docs toolbar (no images, no tables)

## 6. Empty / Error / Loading

- Empty: paper illustration; CTA "Start writing"
- Loading: skeleton 3 lines + toolbar greyed
- Read-only: banner top
- Error: "Couldn't sync"

## 7. Copy

| Surface | Copy |
|---------|------|
| Header | Notes |
| Empty CTA | Start writing |
| Convert prompt | This note's getting long. Convert to a Doc? |
| Clear confirm | Clear all notes? Members will see an empty page. |

## 8. Motion

- Crossfade on read-only switch
- Sync dot pulse when saving

## 9. Accessibility

- WebView ARIA same as docs lite
- Native toolbar buttons labelled
- Keyboard shortcut hints

## 10. Responsive

- Phone: full screen
- Tablet/web: side panel option from channel rail
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED via piped CSS vars
