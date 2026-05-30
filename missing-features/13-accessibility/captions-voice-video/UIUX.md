# Captions for Voice/Video — UI/UX Design

## 1. Design Principles

- **Captions are content.** Treat them as primary, not decorative; never let other UI visually dominate them.
- **Per-speaker clarity.** Colour + name prefix, not just one or the other.
- **User-controlled.** Size, position, opacity, language all changeable mid-call.
- **Privacy is loud.** Every participant gets a visible "Captions on" pill at the top of the call.

## 2. Information Architecture

Where this feature lives:
- Entry points: voice call controls (CC button); Settings → Accessibility → Captions; admin server settings.
- Parent navigation: voice/video call screen.
- Deep links: `flicko://settings/accessibility/captions`.

## 3. Screen Inventory

| # | Screen / Surface | Purpose | States |
|---|------------------|---------|--------|
| 1 | Captions overlay (in call) | Render live captions | speaking, silence, error, paused |
| 2 | Captions toggle on call control bar | Quick on/off | on, off |
| 3 | Captions settings screen | Size, position, opacity, language | content |
| 4 | Pre-call consent banner | Inform participants captions are on | content |
| 5 | Post-call export sheet | Save SRT | content |
| 6 | Server admin captions panel | Enable/disable for server | content |

## 4. Wireframes (ASCII)

### Surface 1 — Captions overlay during a call

```
┌────────────────────────────────────────────────┐
│ ● Captions on             [En ▾]   [⤢]  ✕      │  <- consent pill + lang + reposition
├────────────────────────────────────────────────┤
│                                                │
│       [Speaker tiles / video tiles]            │
│                                                │
│                                                │
├────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────┐  │
│  │ Devon: Welcome everyone, let's start.    │  │
│  │ Asha:  Did you see the new design?       │  │
│  └──────────────────────────────────────────┘  │
│  [ 🅰 size ]   [ ↑ position ]   [ Settings ⚙ ] │
└────────────────────────────────────────────────┘
```

### Surface 2 — Quick toggle on call control bar

```
┌────────────────────────────────────────────────┐
│ [🎤] [🔇] [📷] [📺] [CC] [⋯]                    │
└────────────────────────────────────────────────┘
```

CC button states:
- Off: outlined
- On: filled with `colorScheme.primary`
- Connecting: spinner overlay
- Error: red exclamation

### Surface 3 — Captions settings

```
┌────────────────────────────────────────────────┐
│ ← Captions                                     │
├────────────────────────────────────────────────┤
│ ⦿ Use captions in calls         [▣ ON ]        │
│                                                │
│ Size                                           │
│ ◯ Small  ◉ Medium  ◯ Large                    │
│                                                │
│ Position                                       │
│ ◯ Top  ◯ Center  ◉ Bottom                     │
│                                                │
│ Opacity     50% ─────●───── 100%   85%         │
│                                                │
│ ⦿ Colour by speaker             [▣ ON ]        │
│                                                │
│ Language    [English ▾]                        │
│                                                │
│ Preview                                        │
│ ┌────────────────────────────────────────────┐ │
│ │ Devon: Welcome everyone, let's start.      │ │
│ │ Asha:  Did you see the new design?         │ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

### Surface 4 — Consent banner (call start)

```
┌────────────────────────────────────────────────┐
│ ● Captions are on for this call.               │
│ A live transcript is generated. To save it as  │
│ a file, the host can export an SRT at the end. │
│ [ Got it ]   [ Captions settings ]             │
└────────────────────────────────────────────────┘
```

### Surface 5 — Post-call export sheet

```
┌────────────────────────────────────────────────┐
│ Save captions?                                 │
├────────────────────────────────────────────────┤
│ This call's captions can be saved as an SRT.   │
│                                                │
│ [ Save SRT ]   [ Discard ]                     │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `<CaptionsOverlay>`
- Props: `channelId`, `position`, `size`, `opacity`, `perSpeakerColor`.
- Subscribes to `captions_provider`; renders the latest 3 segments with auto-scroll.
- Tap → expands to last 12 segments (modal).

### `<CaptionsToggleButton>`
- Props: `enabled`, `onToggle`.
- States: off, on, connecting, error.

### `<CaptionPositionPicker>`
- Props: `position: CaptionPosition`, `onChanged`.
- Three radio options (top/center/bottom) with previews.

### `<CaptionSizePicker>`
- Three radios: Small (14sp), Medium (18sp), Large (22sp).

### `<SpeakerColorChip>`
- Tiny colour swatch next to speaker name in caption rendering.
- Colours from a 8-entry safe palette (HC + colour-blind tested).

## 6. Empty / Error / Loading

- **Silence (no speakers):** captions area shows "Listening…" tone-of-voice text.
- **ASR connecting:** "Captions starting…" 1.5 s timeout before fallback.
- **ASR error:** "Captions unavailable. Tap to retry." inline pill.
- **Consent withheld:** captions show but are not persisted; pill says "Captions ephemeral".
- **Loading SRT export:** progress dialog 5 s timeout.

## 7. Copy

| Surface | Copy |
|---------|------|
| Toggle | "Captions" |
| Consent banner | "Captions are on for this call." |
| Consent help | "A live transcript is generated. The host can save it as an SRT file." |
| ASR error | "Captions unavailable. Tap to retry." |
| Post-call save | "Save captions?" |
| Save button | "Save SRT" |
| Discard button | "Discard" |
| Settings | "Captions" |
| Per-speaker toggle | "Colour by speaker" |
| Language picker | "Language" |
| Size labels | "Small" / "Medium" / "Large" |
| Position labels | "Top" / "Center" / "Bottom" |

Voice: clear, neutral, never patronizing.

## 8. Motion

- Caption segments fade in 100 ms (instant under reduced motion).
- Auto-scroll uses 200 ms ease-out.
- Toggle press uses 80 ms tick.

## 9. Accessibility

- Captions overlay is itself a live region (assertive when caption arrives).
- Settings page passes screen reader.
- High-contrast mode replaces palette with HC-safe variants.
- Color-blind mode maps speaker colours through daltonization.
- Reduced-motion mode replaces auto-scroll with snap.

## 10. Responsive

- Phone: overlay docks to bottom by default; user can drag to reposition.
- Tablet/web: overlay can be detached as a side panel.
- Web: keyboard shortcut `C` toggles captions when call is focused.

## 11. Theming

- Caption text colour: `onSurface`; speaker colours from safe palette.
- Background: `surface` at user-selected opacity.
- Outline: 2px when high-contrast active.
- Focus ring on toggle: `focusOutlineHC` in HC mode.

## 12. Per-Speaker Palette

Default 8-colour palette (tested for colour-blind safety with Coblis + Sim Daltonism):

```
#E63946  red       (orangish under deuteranopia, still distinct)
#1D3557  navy
#06D6A0  teal
#F4A261  amber
#9D4EDD  violet
#118AB2  cyan
#FFD166  yellow
#8D99AE  slate
```

Beyond 8 speakers: cycle palette + add a leading symbol (●, ▲, ■, ◆) to disambiguate.
