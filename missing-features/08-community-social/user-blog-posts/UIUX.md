# User Blog Posts — UI/UX Design

## 1. Design Principles

- Editor is calm: hide chrome until needed, focus on the writing
- Reader view typography-first; line length 60-72 chars
- Comments thread compact, not the star
- Mobile-first composition; tablet/web get more room

## 2. Information Architecture

- Entry points: profile page "+ New post", home feed FAB, server "Create"
- Parent: profile, public profile page on web
- Deep link: `flicko://users/<id>/posts/<slug>`, `flicko.app/@user/<slug>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Editor | Write + publish | draft, saving, published, conflict, error |
| 2 | Reader | Read post | content, loading, error, paywall(future) |
| 3 | Profile posts | List own/others' posts | empty, content |
| 4 | Comments thread | Read+post comments | empty, content |
| 5 | Drafts list | Manage drafts | empty, content |

## 4. Wireframes (ASCII)

### Editor

```
+--------------------------------------------------+
| <  New post                       Saved 12s ago  |
+--------------------------------------------------+
|  Title                                           |
|  ______________________________________________  |
|                                                  |
|  Tags  [rust] [riverpod] +                       |
|                                                  |
|  +-- cover  ----------------------+              |
|  |  drag image or upload          |              |
|  +--------------------------------+              |
|                                                  |
|  Write...                                        |
|                                                  |
|  ## Why we picked Riverpod                       |
|                                                  |
|  Last fall the team chose between BLoC and...    |
|                                                  |
|  ![diagram](url)                                 |
|                                                  |
|  ```dart                                         |
|  final provider = Provider((ref) => ...)         |
|  ```                                             |
|                                                  |
+--------------------------------------------------+
| Eye preview     Settings           [ Publish ]   |
+--------------------------------------------------+
```

### Reader

```
+--------------------------------------------------+
|         [cover image, full-bleed]                |
+--------------------------------------------------+
|                                                  |
|  Why we picked Riverpod for v2                   |
|  by @sarah  -  Aurora Devs  -  Mar 12  -  4 min  |
|                                                  |
|  ##############################################  |
|  ##############################################  |
|  ##############################################  |
|                                                  |
|  [code block]                                    |
|                                                  |
|  [image]                                         |
|                                                  |
|  Tags: #rust #riverpod                           |
|                                                  |
|  [ Like 213 ]   [ Comments 44 ]   [ Share ]      |
+--------------------------------------------------+
|  Comments                                        |
|  +------ @riku  ---------------------------+    |
|  | Solid breakdown, helped my migration.   |    |
|  +-----------------------------------------+    |
|     +- @sarah (author): Glad it helped!      |
|                                                  |
|  Add a comment...                                |
+--------------------------------------------------+
```

### Profile posts list

```
+--------------------------------------------------+
| <  @sarah's posts                                |
+--------------------------------------------------+
|  +-- card --------------------------+   thumb    |
|  | Why we picked Riverpod for v2   |   213 likes|
|  | Mar 12 - 4 min                  |   44 comm. |
|  +---------------------------------+            |
|                                                  |
|  +-- card --------------------------+            |
|  | Notes from RustConf             |            |
|  | Feb 28 - 6 min                  |            |
|  +---------------------------------+            |
+--------------------------------------------------+
```

## 5. Component Specs

### `BlogEditor`
- Markdown shortcuts (bold, italic, code, link, list)
- Image drag-and-drop uploads to Appwrite
- Autosave indicator top-right

### `ReaderArticle`
- Reusable on web profile and mobile
- Token usage: `textTheme.bodyLarge` with line-height 1.55

### `CommentThread`
- 1-level deep with replies
- Long-press to copy, report

## 6. Empty / Error / Loading

- **Empty drafts:** "Nothing in drafts. Start a post."
- **Empty profile posts:** "{name} has not posted yet."
- **Error:** banner + retry
- **Loading:** skeleton article with shimmer

## 7. Copy

| Surface | Copy |
|---------|------|
| Title placeholder | Title |
| Body placeholder | Write... |
| Publish | Publish |
| Drafts | Drafts |
| Error | Could not save your draft. Will retry. |
| Empty profile | {name} has not posted yet. |
| Unpublished banner | This post is unlisted. Only people with the link can see it. |

## 8. Motion

- Save indicator pulse 200ms
- Publish: button morph + check 280ms
- Reduced motion: crossfade only

## 9. Accessibility

- Editor announces autosave state via live region
- Code blocks expose language to screen reader
- Reader supports OS-level "Reader mode" via semantics
- Like button is `role=switch`

## 10. Responsive

- Phone: single column, full-bleed images
- Tablet: 720px content column centered
- Web: side rail with table of contents at >=1200

## 11. Theming

- Reader: token `surfaceContainerLowest`, body in `onSurface`
- AMOLED: pure black background; selection accent in author tint
