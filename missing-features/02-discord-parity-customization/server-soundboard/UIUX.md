# Server Soundboard — UI/UX Design

## 1. Design Principles

- Soundboard is a fast, low-friction surface — open, tap, played, dismissed.
- Default clips ship pre-installed; library is never empty.
- Visual feedback is mandatory for hearing-impaired members.
- Reuse `mobile/lib/features/voice/presentation/soundboard_sheet.dart` skeleton (currently a stub) — extend, don't replace.
- Material Motion easings; respect `MediaQuery.disableAnimations`.

## 2. Information Architecture

Where this feature lives:
- Entry point 1: voice-room overflow `⋯` → Soundboard.
- Entry point 2: floating soundboard FAB on the in-call screen (long-press → recent drawer).
- Entry point 3: server settings → Soundboard (mod-only) for upload/manage.
- Deep link: `flicko://servers/:sid/soundboard`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | SoundboardSheet (member) | grid of clips to play | empty, loading, content, cooldown, forbidden |
| 2 | RecentClipsDrawer | last 10 played in this room | empty, content |
| 3 | ClipManageScreen (mod) | rename/disable/delete; reorder | content, error |
| 4 | ClipUploadScreen (mod) | pick file → name + emoji → upload | picking, uploading, processing, ready, error |
| 5 | SoundboardSettings (mod) | per-role perms, cooldown, slot status | content |
| 6 | InCallVisualIndicator | shows clip name/emoji during playback | hidden, visible |

## 4. Wireframes (ASCII)

### Screen 1 — SoundboardSheet

```
┌────────────────────────────────────────────┐
│  Soundboard                Recent  ⋯       │
├────────────────────────────────────────────┤
│  🔍 Search clips                           │
│                                            │
│  Tagged                                    │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐      │
│  │ 🏆   │ │ 😂   │ │ 🎉   │ │ 🦗   │     │
│  │ GG   │ │ Bruh │ │ Hype │ │ Crick│     │
│  └──────┘ └──────┘ └──────┘ └──────┘      │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐      │
│  │ 🚨   │ │ 💀   │ │ 🎺   │ │ 🐱   │     │
│  │ Alert│ │ Dead │ │ Fanfa│ │ Meow │     │
│  └──────┘ └──────┘ └──────┘ └──────┘      │
│                                            │
│  Cooldown: 5s         48 clips, 12 used    │
└────────────────────────────────────────────┘
```

Each chip pulses on tap (haptic + 100ms scale 1.0→0.95→1.0). On cooldown, chip is greyed with a CCW progress ring.

### Screen 2 — RecentClipsDrawer

```
┌────────────────────────────────────────────┐
│ Recently played                    Close   │
├────────────────────────────────────────────┤
│  🏆 GG          @priya     2 sec ago       │
│  😂 Bruh        @liam      45 sec ago      │
│  🎺 Fanfare     @maya      1 min ago       │
│  🚨 Alert       @priya     3 min ago       │
└────────────────────────────────────────────┘
```

### Screen 3 — ClipManageScreen

```
┌────────────────────────────────────────────┐
│ ←  Manage clips                  Add ＋    │
├────────────────────────────────────────────┤
│  ≡  🏆  GG (1.2s · 18 KB)            ⋯    │
│  ≡  😂  Bruh (0.8s · 12 KB)          ⋯    │
│  ≡  🎉  Hype (3.0s · 42 KB)          ⋯    │
│                                            │
│  12 / 48 used                              │
└────────────────────────────────────────────┘
```

Drag handle on left for reorder. `⋯` opens rename / change emoji / disable / delete.

### Screen 4 — ClipUploadScreen

```
┌────────────────────────────────────────────┐
│ ←  Upload clip                    Save     │
├────────────────────────────────────────────┤
│  🎵  fanfare.mp3                           │
│      2.4 s · 32 KB · mp3 → opus            │
│      ▶ Preview                             │
│                                            │
│  Name                                      │
│  ┌──────────────────────────────────┐      │
│  │ Fanfare                          │      │
│  └──────────────────────────────────┘      │
│                                            │
│  Emoji                                     │
│  ┌──────────────────────────────────┐      │
│  │ 🎺  pick                          │      │
│  └──────────────────────────────────┘      │
│                                            │
│  ☑  I have rights to use this audio       │
└────────────────────────────────────────────┘
```

### Screen 5 — SoundboardSettings

```
┌────────────────────────────────────────────┐
│ ←  Soundboard                              │
├────────────────────────────────────────────┤
│  Cooldown                                  │
│  [○━━━━━●━━━━━━━━━━━]  5 s                 │
│                                            │
│  Who can play                              │
│  @everyone               [✓]               │
│  @members                [✓]               │
│  @new-members            [ ]               │
│                                            │
│  Who can upload                            │
│  @mods                   [✓]               │
│  @everyone               [ ]               │
│                                            │
│  Slot count                                │
│  48 free + 0 with Plus                     │
│  Get Plus → 96 slots                       │
└────────────────────────────────────────────┘
```

### Screen 6 — In-call visual indicator

```
┌────────────────────────────────────────────┐
│   Avatar tiles…                            │
│                                            │
│             🏆 GG  by Priya                │
│             ━━━━━━━━━─────                 │  ← progress bar matching clip duration
└────────────────────────────────────────────┘
```

Persists for clip duration + 800 ms.

## 5. Component Specs

### `ClipChip`
- Props: `Clip clip`, `bool onCooldown`, `Duration cooldownRemaining`, `VoidCallback onTap`.
- States: idle / pressed / cooldown / disabled / forbidden.
- Token usage: `colorScheme.surfaceContainerHigh` background, accent ring on focus.
- Tap target: 88×88pt. Min 56pt height for the emoji+label stack.

### `CooldownRing`
- CCW circular progress, 2pt stroke, on top of chip.
- Updates at 60fps using a `Ticker`; clears when remaining ≤ 0.

### `VisualPlayIndicator`
- Bottom-of-room banner showing clip name, player, and a duration progress bar. Auto-dismisses.

### `EmojiPicker`
- Reuses existing `mobile/lib/features/server_channels/.../emoji_picker.dart`.

## 6. Empty / Error / Loading

- **Empty (mod manage):** illustration + "Drop your first clip" + Add CTA.
- **Empty (member sheet):** never empty — defaults always populate.
- **Loading:** skeleton chip grid (12 chips) for ≤300 ms.
- **Cooldown:** chip greyed; ring animates; tap shows toast "Wait {n}s".
- **Forbidden:** chip greyed; tooltip "Your role can't play sounds in this server."
- **Upload error:** inline banner above form: "Couldn't upload — try a smaller clip."

## 7. Copy

| Surface | Copy |
|---------|------|
| Sheet title | Soundboard |
| Search hint | Search clips |
| Cooldown toast | Wait {n}s before the next clip. |
| Forbidden toast | Your role can't play sounds here. |
| Upload title | Upload clip |
| Save | Save |
| File hint | Up to 5 seconds. MP3, M4A, OGG, or WAV. |
| Rights checkbox | I have rights to use this audio |
| Manage empty | Drop your first clip — server members can hear it in voice. |
| Settings cooldown label | Cooldown |
| Settings slots line | {used} / {total} used |
| Plus upsell | Get Plus → 96 slots |
| Report option | Report clip |

## 8. Motion

- Chip tap: 100ms scale + 50ms haptic.
- Cooldown ring: continuous, drains over `cooldown_seconds`.
- In-call indicator: slide-up 200ms, slide-down 200ms.
- Reduced motion: scale becomes opacity flash; ring becomes a static label "{n}s".

## 9. Accessibility

- Every chip Semantics: `"{name}, {duration} seconds, tap to play. {cooldown remaining} seconds remaining."`
- Visual indicator visible by default — not optional.
- Closed-caption style label for hearing-impaired (always-on).
- Color contrast: chip label ≥4.5:1 in all themes.
- Keyboard: tab through grid; Enter plays.
- Reduced motion: visual indicator doesn't slide; appears/disappears instantly.

## 10. Responsive

- Phone (≤600dp): 4 columns.
- Foldable (600–840dp): 6 columns.
- Tablet/web (≥840dp): 8 columns.

## 11. Theming

- Chip uses `colorScheme.surfaceContainerHigh`; emoji is platform-native.
- Accent color (when 09-customization ships) tints the cooldown ring + active chip border.
