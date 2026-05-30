# Server Gallery — UI/UX Design

## 1. Design Principles

- Mosaic that respects original aspect ratios
- Blurry NSFW by default; tap to reveal
- Lightbox is keyboard, swipe, and pinch friendly
- Curating tools sit close to the artifacts

## 2. Information Architecture

- Entry points: Server -> Members -> Gallery tab; channel header overflow menu
- Parent: server top-level navigation
- Deep link: `flicko://server/<id>/gallery`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Gallery grid | Browse | empty, loading, content, error |
| 2 | Lightbox | Full media | content, zoom, slideshow |
| 3 | Filters sheet | Channel/author/date | content |
| 4 | Author panel | Items by one author | content, empty |
| 5 | Settings -> Gallery | Owner config | content |

## 4. Wireframes (ASCII)

### Gallery grid

```
+--------------------------------------------------+
| <  Aurora Devs - Gallery       filter (V)  ...   |
+--------------------------------------------------+
|  [#art]  [#screens]  [Featured]  [All channels]  |
+--------------------------------------------------+
|  +-------+  +-----+ +--------+                   |
|  | img   |  |img  | |  img   |                   |
|  | tall  |  |     | |        |                   |
|  +-------+  |     | |        |                   |
|  +-------+  +-----+ +--------+                   |
|  | gif   |  +-----+ +--------+                   |
|  +-------+  |video| | image  |                   |
|             +-----+ +--------+                   |
|  ...                                              |
+--------------------------------------------------+
|  Pull to refresh                                  |
+--------------------------------------------------+
```

### Lightbox

```
+--------------------------------------------------+
| <  by @riku  -  in #art  -  Apr 12  [F]  [...]   |
+--------------------------------------------------+
|                                                  |
|              [   media full-bleed   ]            |
|                                                  |
+--------------------------------------------------+
|  caption from message (first line if any)        |
|                                                  |
|  [ Open message ]   [ Save ]   [ Share ]   v 12  |
+--------------------------------------------------+
```

### Filters sheet

```
+--------------------------------------------------+
|  Filters                                         |
+--------------------------------------------------+
|  Channels    [#art] [#screens] +                 |
|  Authors     @riku +                             |
|  Date        [ Last 7 days ]                     |
|  Type        [ Images ]  [ Gifs ]  [ Video ]     |
|  Featured    [ off ]                              |
|  Show NSFW   [ off ]                              |
|                                                  |
|                              [ Apply ]            |
+--------------------------------------------------+
```

### Settings -> Gallery

```
+--------------------------------------------------+
| <  Gallery                                       |
+--------------------------------------------------+
|  Enable                       [ on  /  off ]     |
|  Blur NSFW by default         [ on ]              |
|  Excluded channels             [ select... ]      |
|  Retention                     [ 365 days ]       |
|                                                  |
|  Featured items                                  |
|     [ Manage ]                                    |
+--------------------------------------------------+
```

## 5. Component Specs

### `GalleryTile`
- Props: thumb URL, aspect ratio, nsfw, kind
- Aspect-aware sizing, lazy load via `extended_image`

### `Lightbox`
- Pinch zoom, swipe between, double-tap to fit
- ESC and back nav return to grid

## 6. Empty / Error / Loading

- **Empty:** "No images yet. Once people share, they show up here."
- **Error:** banner with retry; falls back to last cached page
- **Loading:** shimmering tiles in the same layout

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Gallery |
| Empty | No images yet. |
| NSFW reveal | Tap to reveal |
| Hide self confirm | Hide your photo from the gallery? It stays in the channel. |
| Feature toggle | Featured |

## 8. Motion

- Tile bloom on first paint 220ms staggered
- Lightbox open hero animation 280ms
- Reduced motion: crossfade

## 9. Accessibility

- Each tile announces author, date, kind, alt text if any
- Lightbox keyboard arrows for navigation; ESC to close
- NSFW blur respected by screen reader (announces "Sensitive content")

## 10. Responsive

- Phone: 2-3 column dynamic mosaic
- Tablet: 4-5 column
- Web: 6 column at >=1280

## 11. Theming

- Tiles use neutral surface; featured items get tertiary tint border
