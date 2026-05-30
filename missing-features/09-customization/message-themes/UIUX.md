# Message Themes — UI/UX Design

## 1. Design Principles

- Show, don't describe — preview must update on every option change.
- Don't ship a bad default — keep the current dense list-view as the implicit default for existing users.
- Density and shape are independent axes; tail is paired with shape (rounded/classic only).
- Reduced motion respected — no shape morph animations.

## 2. Information Architecture

Where this lives:
- **Entry points:** Settings → Appearance → Chat appearance.
- **Parent navigation:** Appearance settings.
- **Deep links:** `flicko://settings/appearance/chat`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Chat appearance | Pick shape + tail + density | content |
| 2 | Live preview pane | Mock messages | content |

## 4. Wireframes (ASCII)

### Screen 1 — Chat appearance

```
+--------------------------------------------+
| <  Chat appearance                         |
+--------------------------------------------+
| Bubble shape                               |
|  ( ) Square                                |
|  (o) Rounded                               |
|  ( ) Classic (no bubble)                   |
|                                            |
| Tail (rounded only)                        |
|  [ x ]  on   [   ]  off                    |
|                                            |
| Density                                    |
|  ( ) Compact                               |
|  (o) Cozy                                  |
|  ( ) Comfy                                 |
|                                            |
+--------------------------------------------+
| Preview                                    |
|                                            |
|        +-------------------+               |
|        | hi from sky       |               |
|        +-------------------+ <- tail       |
|  +-----+                                   |
|  |yo!! |                                   |
|  +-----+                                   |
|                                            |
+--------------------------------------------+
|        ( Reset to defaults )               |
+--------------------------------------------+
```

### Compare wireframe — shape variants

```
square+tail off          rounded+tail on        classic
+-----+                  +-------+               hi from sky
| hi  |                  | hi    |               yo
+-----+                  +-------+\             
+-----+                                          
| yo  |                  +-------+               
+-----+                  | yo    |               
                         +/------+               
```

### Compare — density

```
compact         cozy            comfy
sky: hi         sky: hi         sky:
yo              yo               hi
[3 lines]       [3 lines]       yo
                                
                                [3 lines]
```

## 5. Component Specs

### `BubbleShapeRadio`
- Three radio chips with mini icon previews.

### `BubbleTailToggle`
- Disabled when shape is `classic`.

### `DensityRadio`
- Three options; preview updates immediately.

### `ChatPreviewPane`
- Renders 4 mock messages with avatar, name, body, timestamp, reaction.
- Includes reply, image, voice samples to verify all message types.

## 6. Empty / Error / Loading

- No empty/error states — settings always have a value.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Chat appearance |
| Square | Square |
| Rounded | Rounded |
| Classic | Classic (no bubble) |
| Tail | Show tail on your messages |
| Compact | Compact |
| Cozy | Cozy |
| Comfy | Comfy |
| Reset | Reset to defaults |

Voice: friendly, second-person.

## 8. Motion

- Shape change: instant (no morph animation v1).
- Density change: animated padding 200ms ease.
- Reduced motion: instant for both.

## 9. Accessibility

- Tap targets ≥44pt regardless of density.
- High contrast: bubble outline at 1.5px in high-contrast mode.
- Screen reader: announce "Bubble shape: rounded".
- Compact density does not reduce font below 14sp.

## 10. Responsive

- Phone: stacked options + preview below.
- Tablet/web: options left, preview right.

## 11. Theming

Bubble fill colors come from `colorScheme.primaryContainer` (own messages) and `colorScheme.surfaceContainer` (others). Tail painter uses same fills, so themes carry through automatically.
