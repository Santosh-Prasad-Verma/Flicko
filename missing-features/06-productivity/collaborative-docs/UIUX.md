# Collaborative Docs — UI/UX Design

## 1. Design Principles

- WebView editor must look identical to native rest-of-app: same font stack, same theme tokens piped via `postMessage`
- Cursor colors picked from a deterministic 12-color palette so the same user keeps the same color
- Presence avatars top-right of the editor frame; cursors carry name labels that fade after 2s of idle
- Touch-first: floating action menu over selection, same as iOS Notes
- Match Flicko app bar height; sticky save indicator inside the bar

## 2. Information Architecture

- Entry points:
  1. Channel header "Docs" pill (count badge)
  2. Server side rail "Docs" (cross-channel list filtered by access)
  3. Deep link `flicko://doc/<id>`
- Hierarchy: server -> channel -> doc (no nesting in v1)

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Doc List | Channel docs index | empty, loading, content, error |
| 2 | Editor | Real-time editing surface | connecting, synced, reconnecting, read-only, offline |
| 3 | Version History | Browse + restore snapshots | loading, content, comparing |
| 4 | Comments Drawer | Threaded comments | empty, content |
| 5 | ACL Sheet | Manage who can edit | content, saving |

## 4. Wireframes (ASCII)

### Screen 1 — Doc List

```
┌────────────────────────────────────────────────────┐
│ ←  #mod-room · Docs                       [+]     │
├────────────────────────────────────────────────────┤
│ Pinned                                             │
│ ┌────────────────────────────────────────────────┐ │
│ │ 📘 Onboarding Playbook                         │ │
│ │    Updated 2h ago · by @alex · 4 editors       │ │
│ ├────────────────────────────────────────────────┤ │
│ │ 📘 Server Rules                                │ │
│ │    Updated 3d ago · 28 revisions               │ │
│ └────────────────────────────────────────────────┘ │
│ Recent                                             │
│ ┌────────────────────────────────────────────────┐ │
│ │ 📄 Q3 Roadmap        Updated 5d ago            │ │
│ │ 📄 Event run-of-show Updated 1w ago            │ │
│ └────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

### Screen 2 — Editor

```
┌────────────────────────────────────────────────────┐
│ ← Onboarding Playbook        ( A )( B )( C ) +1  ⋮│
│   Auto-saved · Synced ✓                            │
├────────────────────────────────────────────────────┤
│ # Onboarding Playbook                              │
│                                                    │
│ ## Welcome                                         │
│ Hello new mod. This is the playbook|              │
│                              ^cursor (alex)        │
│                                                    │
│ ## First week checklist                            │
│  - [ ] Read server rules                           │
│  - [x] Meet the mod team                           │
│                                                    │
│ ## Helpful commands                                │
│ ```                                                │
│ /ban @user reason                                  │
│ /timeout @user 10m                                 │
│ ```                                                │
│ ┌──────────────────────────────────────┐           │
│ │ 💬 priya: should we mention rate ... │           │
│ │ 2 replies · open                     │           │
│ └──────────────────────────────────────┘           │
├────────────────────────────────────────────────────┤
│ [B] [I] [S] [H1] [H2] [•] [1.] [☐] [{ }] [@] [📷] │
└────────────────────────────────────────────────────┘
```

### Screen 3 — Version History

```
┌────────────────────────────────────────────────────┐
│ ← Version history · Onboarding Playbook            │
├──────────────────────┬─────────────────────────────┤
│ Now (rev 28)         │ Selected: rev 12            │
│ 2h ago · @alex       │ "before launch" · 7d ago    │
│ ──────────────────── │                             │
│ rev 27 · 3h          │ # Onboarding Playbook       │
│ rev 26 · 5h          │ ## Welcome                  │
│ ★ rev 12 — before    │ Hello new mod.              │
│   launch  · @alex    │ ...                         │
│ rev 11 · 9d          │                             │
│ ...                  │ [ Restore this version ]    │
└──────────────────────┴─────────────────────────────┘
```

### Screen 4 — Comments Drawer

```
┌────────────────────────────────────────────────────┐
│ Comments (3)                              ✕        │
├────────────────────────────────────────────────────┤
│ ● open                                             │
│ @priya · 2h                                        │
│ should we mention rate limits?                     │
│   @alex: yes, adding under "Helpful commands"      │
│   @priya: ✓                                        │
│ [ Reply ]   [ Resolve ]                            │
├────────────────────────────────────────────────────┤
│ ✓ resolved                                         │
│ @sam · 1d  link to api docs                        │
└────────────────────────────────────────────────────┘
```

## 5. Component Specs

### `PresenceAvatars`
- Up to 3 avatars + "+N"
- Each avatar bordered with that user's cursor color
- Tap shows roster

### `EditorToolbar`
- Sticky bottom on phone, top on tablet
- Buttons: bold, italic, strike, h1, h2, list, ordered, todo, code block, mention, image
- Disabled state when read-only

### `CommentPin`
- Renders in left margin aligned to anchor line
- Open=filled, resolved=outline
- Tap opens drawer scrolled to thread

## 6. Empty / Error / Loading

- Empty list: book illustration; "No docs yet" + "+ New doc"
- Loading editor: skeleton with toolbar greyed; "Connecting…"
- Reconnecting: amber banner top
- Read-only: lock icon next to title; "View only" pill
- Offline: grey banner; toolbar disabled

## 7. Copy

| Surface | Copy |
|---------|------|
| New doc CTA | New doc |
| Empty title | No docs yet |
| Empty body | Use docs to keep playbooks, FAQs, and notes that survive scroll. |
| Save indicator | Synced ✓ / Saving… / Offline |
| Restore confirm | Restore rev {n}? It'll create a new revision with this content. |
| Comment placeholder | Add a comment |

Voice: practical, second-person.

## 8. Motion

- Cursor labels fade after 2s idle (200ms)
- Toolbar slide-in 250ms on focus
- Reduced motion: instant cursor labels

## 9. Accessibility

- Editor: WebView injects ARIA roles via Tiptap a11y plugin
- Native shell exposes Semantics for toolbar buttons
- Cursor labels also include user name in screen reader announcement
- Color paired with user initials so color-blind users still differentiate

## 10. Responsive

- Phone: editor full-bleed, comments drawer overlays
- Tablet: comments drawer slides in beside, no overlay
- Web: three-pane (list / editor / comments)
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
- WebView CSS variables piped from app theme on load and on theme change via postMessage
- Honors server accent for cursor of channel owner
