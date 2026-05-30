# Gesture Controls — UI/UX

## 1. Principles
Discoverable, undoable, optional. Every gesture has a non-gesture equivalent in long-press menu.

## 2. Architecture
- Gestures owned by message-row widget; routed via `Dismissible`/`GestureDetector` composites.
- Settings → Accessibility → Gestures: master toggle + per-gesture toggles.

## 3. Screens
| # | Screen | States |
|---|--------|--------|
| 1 | Gesture settings | default / customized |
| 2 | First-run hint overlay | shown once / dismissed |
| 3 | Inline action ghost while dragging | tracking / triggered |

## 4. Wireframes

### Swipe-to-reply
```
[message]→ ───────────  ↩ Reply
            ░░░░░░░░░  ▓▓▓▓▓
       (pull right; release at 80dp triggers)
```

### Long-press menu
```
┌────────────────────────────┐
│ Reply           ↩          │
│ React           😀         │
│ Pin             📌         │
│ Copy text       ⧉          │
│ Edit            ✏️         │
│ Delete          🗑         │
│ Report          ⚑          │
└────────────────────────────┘
```

### Gesture settings
```
┌────────────────────────────────┐
│ Gestures                       │
├────────────────────────────────┤
│ Swipe to reply        [ON ▣]   │
│   Direction  ◯ R-to-L ● L-to-R │
│ Double-tap to react   [ON ▣]   │
│   Default 😀 (tap to change)   │
│ Long-press menu       [ON ▣]   │
│ 3-finger undo         [ON ▣]   │
│ 2-finger swipe nav    [ON ▣]   │
│                                │
│ Haptics               [ON ▣]   │
└────────────────────────────────┘
```

## 5. Components
- `<GestureMessageRow>` wraps existing `MessageBubble`.
- `<UndoSnackbar>` shows 5-s window, "Undo" tappable.

## 6. Empty/Error
- First-run: subtle hint card "Try swiping a message to reply" (dismiss permanent).
- If long-press disabled: degrade to right-click on web/desktop.

## 7. Copy
| Surface | Copy |
|---------|------|
| First hint | Swipe a message to reply |
| Settings header | Gestures |
| Undo snackbar | Action undone |

## 8. Motion
- Drag tracks finger 1:1 to threshold then stops.
- Snap-back curve: easeOutCubic 200ms.
- Haptic on threshold cross only (one buzz, not continuous).

## 9. Accessibility
- All gestures duplicated in long-press menu and keyboard shortcuts (web/desktop).
- Screen-reader: gestures effectively disabled; rotor uses menu items.
- Reduced-motion: drop translation animation; show static reveal of action label.

## 10. Responsive
- Tablet: gestures still apply; mouse equivalents (right-click, hover-double-click).
- Web: shortcut `R` for reply, double-click for react.

## 11. Theming
- Action icons inherit accent color.
- Reveal background uses semantic colors (reply=primary, delete=error).
