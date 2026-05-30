# Widget Builder — UI/UX Design

## 1. Design Principles

- Drag-drop is the primary interaction; show a visible drop zone always.
- Right rail shows properties of the selected block; nothing else.
- Live preview at all times — no separate "Preview" tab; the canvas IS the preview.
- Snippet generator is a sticky CTA after at least 1 block placed.
- Mobile-first: builder also usable on iPad/foldable.

## 2. Information Architecture

Where this lives:
- **Entry points:** Server Settings (mobile) → "Embed widgets" → opens browser to builder. Direct URL `widgets.flicko.app/builder/:sid`.
- **Parent navigation:** Server settings.
- **Deep links:** mobile deep link `flicko://servers/<sid>/widgets` → opens external browser.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Builder canvas | drag-drop layout | empty, content, saving, error |
| 2 | Block palette (left rail) | drag source | content |
| 3 | Properties panel (right rail) | edit selected block | none-selected, editing |
| 4 | Preview pane | live rendered embed | loading, content |
| 5 | Snippet sheet | copy iframe + script | content |

## 4. Wireframes (ASCII)

### Screen 1 — Builder canvas

```
+-------------------------------------------------------------+
| Flicko Widget Builder    [my-server v]   [Save]  [Snippet]  |
+----+--------------------------------------+-----------------+
| BL | Canvas (drop here)                   | Properties      |
| OC |                                      |                 |
| KS | +-------------------+                | type: member    |
|    | | member_count      |                | count           |
| [#]|  | 4,201 members    |                |                 |
| [@]|  +-------------------+                | label:          |
| [^]|                                      | [Members      ] |
| [*]|  +-------------------+                |                 |
| [v]|  | recent_posts      |                | channel:        |
|    | | * @mira: hi        |                | [#general    v] |
|    | | * @noah: yo         |                |                 |
|    | +-------------------+                |                 |
+----+--------------------------------------+-----------------+
| frame ancestors: [ mygame.com, www.mygame.com           ]   |
+-------------------------------------------------------------+
```

### Screen 2 — Block palette

```
+----+
| BL |
| OC |
| KS |
+----+
| [#] member_count
| [@] online_roster
| [^] recent_posts
| [*] event_list
| [v] leaderboard
| [+] join_cta
| [B] banner
| [#] channel_highlight
+----+
```

### Screen 5 — Snippet sheet

```
+------------------------------------------------+
|  Embed snippet                          x      |
+------------------------------------------------+
| Choose a flavor                                |
|  (o) iframe (simple)                           |
|  ( ) script (shadow DOM)                       |
|                                                |
|  +--------------------------------------------+|
|  | <iframe src="https://embed.flicko.app/    || 
|  | abc-123" style="border:0;width:320px;     ||
|  | height:480px"></iframe>                   ||
|  +--------------------------------------------+|
|        ( Copy snippet )                        |
|                                                |
|  Allow these domains to embed:                 |
|   [ mygame.com, www.mygame.com           ]     |
+------------------------------------------------+
```

### Embed render — phone view

```
+--------------------+
| Members 4,201      |
|                    |
| Recent posts       |
| - mira: hi         |
| - noah: yo         |
|                    |
| [ Join us ]        |
+--------------------+
```

## 5. Component Specs

### `CanvasGrid`
- 12-col grid, 8px gutter.
- Drop targets snap.

### `BlockShell`
- Wraps each block; handles hover, selected, drag.
- Token usage: `colorScheme.surfaceContainer`, outline 1px on hover.

### `PropertiesPanel`
- Renders a per-block form using a JSON schema declared by each block.

### `SnippetGenerator`
- Two flavors: iframe and script.
- Validates frame-ancestors list (must be valid hostnames).

## 6. Empty / Error / Loading

- **Empty canvas:** illustration + text "Drag a block here to start" + 3 starter templates.
- **Saving:** small chip "Saving..." in top bar.
- **Error:** banner "Couldn't save. Retry."
- **Loading preview block:** shimmer in the block frame.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Flicko Widget Builder |
| Save CTA | Save |
| Snippet CTA | Snippet |
| Empty canvas | Drag a block to start |
| Snippet sheet title | Embed snippet |
| Hostname helper | Only these sites can embed your widget. |

Voice: clear, minimal, second-person.

## 8. Motion

- Drag: 150ms ease-out.
- Drop snap: 200ms spring.
- Block delete: scale to 0 + opacity 0 over 180ms.
- Reduced motion: instant.

## 9. Accessibility

- Keyboard drag: `Space` to grab, arrow keys to move, `Space` to drop.
- Tap targets ≥44pt for handle, delete, edit.
- Properties panel forms have explicit labels.
- High contrast mode: outlines instead of subtle backgrounds.
- Screen reader announces "Block: member count moved to row 1, column 1".

## 10. Responsive

- Desktop (≥1024): three-pane layout.
- Tablet (768-1023): collapsible right rail.
- Mobile (≤767): single-pane with bottom sheet for properties; drag-drop becomes tap-and-place.

## 11. Theming

Builder UI itself uses Flicko's theme. The widget's own palette is independent — owner picks brand color. Light/dark/auto modes are stored on the widget.
