# Controller Support — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Action hint overlay | Bottom strip with A/B/X/Y |
| 2 | Settings: Controller | Preset, rebinds, test page |
| 3 | Virtual keyboard | Text input via D-pad |
| 4 | Test page | Verify each button maps |

## Wireframes

### Hint overlay
```
[A]Select  [B]Back  [Y]Menu  [LB]Mute  [≡]Server list
```

### Settings
```
┌──────────────────────────────┐
│ Controller                    │
├──────────────────────────────┤
│ Use controller          [ON ▣]│
│ Preset                       │
│   ◉ Default Xbox/PS         │
│   ◯ Steam Deck              │
│   ◯ Custom                  │
│ Vibration               [ON ▣]│
│ Show button hints       [ON ▣]│
│                              │
│ [ Test buttons ] [ Rebind ]  │
└──────────────────────────────┘
```

### Virtual keyboard
```
┌──────────────────────────────┐
│ q w e r t y u i o p   ⌫     │
│ a s d f g h j k l    ↵      │
│ z x c v b n m  ,  .          │
│  [⇧] [123] [   ␣   ] [emoji] │
└──────────────────────────────┘
[A]type  [B]back  [Y]Caps  [LB]switch
```

## Components
- `<ControllerHintOverlay>` reads current focus context for hints.
- `<FocusableSurface>` wraps lists/cards; provides D-pad nav.

## Empty/Error
- "No controller detected" tap to retry.
- Battery low (<10%): toast.

## Copy
| Surface | Copy |
|---------|------|
| Hint title | Controls |
| Setting | Use controller |
| Test prompt | Press any button to test |

## Motion
- Focus highlight pulses briefly on change.
- Reduced-motion: static highlight.

## Accessibility
- Hint strip readable by screen reader.
- All hints duplicated as text labels (not icon-only).

## Responsive
- Hint strip collapses on mobile-portrait (no controller scenario).

## Theming
- Hint icons match preset (Xbox/PS/generic letters).
