# Channel Backgrounds — UI/UX Design

## 1. Design Principles

- Background is *atmospheric*, not informational. Text and chrome stay readable at all opacities.
- Defaults are conservative: 30% in dark mode, 12% in light. Member can crank up but can't go below 0.
- Reuse `mobile/lib/features/shared/presentation/widgets/` chrome (`FlickoTopBar`, `FlickoBottomSheet`).
- Material Motion easings; respect `MediaQuery.disableAnimations`.
- Every interactive element ≥44pt tap target with Semantics label.

## 2. Information Architecture

Where this feature lives:
- Entry point 1 (admin): Channel settings → Appearance → Background.
- Entry point 2 (member): Chat top-bar `⋯` → "Background opacity".
- Entry point 3 (member): Settings → Chat → "Channel backgrounds" master toggle.
- Parent navigation: existing Channel Settings flow.
- Deep link: `flicko://servers/:sid/channels/:cid/settings/background`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | BackgroundUploadScreen (admin) | Pick + crop + confirm upload | empty, picking, cropping, uploading, processing, ready, error |
| 2 | OpacitySheet (member) | Adjust opacity for this channel | idle |
| 3 | GlobalBackgroundsToggle (member) | Disable backgrounds app-wide | on/off |
| 4 | ChannelScreen w/ background layer | Renders background behind chat | placeholder, loading, ready, disabled |
| 5 | ProcessingBanner | Shown to admin during variant gen | inline |

## 4. Wireframes (ASCII)

### Screen 1 — BackgroundUploadScreen (admin)

```
┌────────────────────────────────────────────┐
│ ←  Channel background                      │
├────────────────────────────────────────────┤
│                                            │
│   ┌──────────────────────────────────┐     │
│   │  current background preview      │     │
│   │  (blurred, with sample message    │     │
│   │   bubble overlay)                 │     │
│   └──────────────────────────────────┘     │
│                                            │
│   [  📷  Choose image          ]          │
│   [  🗑  Remove background     ]          │
│                                            │
│   Tips                                     │
│   • Less busy images read better.          │
│   • We'll dim it for you so text shines.   │
│   • Max 8 MB. JPG, PNG, or WebP.           │
│                                            │
└────────────────────────────────────────────┘
```

After picking:

```
┌────────────────────────────────────────────┐
│ ←  Choose focal point             Upload   │
├────────────────────────────────────────────┤
│                                            │
│   ┌──────────────────────────────────┐     │
│   │  image with draggable focus      │     │
│   │  reticle — keeps subject in      │     │
│   │  view on phones and tablets       │     │
│   └──────────────────────────────────┘     │
│                                            │
│   Sample message overlay                   │
│   ┌──────────────────────────────┐         │
│   │ Sample text at 30% opacity   │         │
│   └──────────────────────────────┘         │
└────────────────────────────────────────────┘
```

### Screen 2 — OpacitySheet (member)

```
┌────────────────────────────────────────────┐
│              Background opacity            │
│                                            │
│   ▢━━━━━●━━━━━━━━━━━━━━━━━▢                │
│   0%        30%                  80%       │
│                                            │
│   [  Use server default  ]                 │
│   [  Turn off for this channel  ]          │
│                                            │
└────────────────────────────────────────────┘
```

### Screen 3 — GlobalBackgroundsToggle

```
┌────────────────────────────────────────────┐
│ Channel backgrounds                  [ON]  │
├────────────────────────────────────────────┤
│ Show admin-set images behind channel chat. │
│ Turn off to save data and reduce visual    │
│ noise.                                     │
└────────────────────────────────────────────┘
```

### Screen 4 — Channel screen with background

```
┌────────────────────────────────────────────┐
│ # gaming-talk                       ⋯      │  ← chrome stays solid
├────────────────────────────────────────────┤
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  ← background layer (30%)
│ ░░ ┌──────────────────┐                  ░░│
│ ░░ │ @maya  hey team  │                  ░░│  ← message bubbles solid
│ ░░ └──────────────────┘                  ░░│
│ ░░ ┌──────────────────────────────┐      ░░│
│ ░░ │ @liam  ranked at 9?          │      ░░│
│ ░░ └──────────────────────────────┘      ░░│
│                                            │
├────────────────────────────────────────────┤
│ [Type a message]                       ➤  │
└────────────────────────────────────────────┘
```

### Screen 5 — Admin processing banner

```
┌────────────────────────────────────────────┐
│ ⟳  Optimizing for everyone… ~5s            │
└────────────────────────────────────────────┘
```

## 5. Component Specs

### `ChannelBackgroundLayer`
- Props: `Channel channel`, `double opacity`, `bool dataSaver`, `bool reducedMotion`.
- Renders a `Stack`: BlurHash placeholder → fade-in mobile variant → optional dim scrim.
- Emits a `RepaintBoundary` so message list scrolling doesn't repaint background.
- If `dataSaver` true OR `reducedMotion` true OR member toggled off → BlurHash only (no full image fetch).

### `OpacitySlider`
- Material 3 slider, range 0–80, step 5.
- Live preview: a sample chat bubble updates as the user drags.

### `BackgroundFocusPicker`
- 16:9 + 9:16 framing previews shown side by side so admin sees how the image crops on phone vs tablet.

## 6. Empty / Error / Loading

- **Empty:** "No background set. The channel uses your server's default."
- **Error (upload):** inline banner above upload row: "{reason}, try a smaller image." Reason mapped from server error code.
- **Loading (upload in progress):** progress bar + "{percent}%" + cancel button.
- **Processing (post-upload, variants generating):** inline banner above message list visible only to admins.
- **Moderated:** modal "This image was blocked. Try another." (reason omitted for safety).

## 7. Copy

| Surface | Copy |
|---------|------|
| Admin screen title | Channel background |
| Choose CTA | Choose image |
| Remove CTA | Remove background |
| Upload CTA | Upload |
| Tip 1 | Less busy images read better. |
| Tip 2 | We'll dim it for you so text shines. |
| Tip 3 | Max 8 MB. JPG, PNG, or WebP. |
| Member sheet title | Background opacity |
| Use default | Use server default |
| Turn off | Turn off for this channel |
| Global toggle title | Channel backgrounds |
| Global toggle help | Show admin-set images behind channel chat. Turn off to save data. |
| Processing banner | Optimizing for everyone... |
| File too big | That image is over 8 MB. Try compressing it. |
| Bad type | We support JPG, PNG, and WebP. |
| Moderated | This image was blocked. Try another. |

## 8. Motion

- Background fade-in: 220ms ease-out from BlurHash placeholder to mobile variant.
- Opacity slider: live update; no animation needed.
- Processing banner: slide down 200ms; auto-dismiss on `channel.background.updated` event.
- Reduced motion: replace fade-in with instant swap; no parallax.

## 9. Accessibility

- Background is decorative — `Semantics(excludeSemantics: true)` on the layer.
- Opacity slider announces percentage on change; min/max announced.
- High-contrast mode (system): force opacity to 0% override (background hidden).
- Color contrast: at default opacity, message text contrast verified ≥4.5:1 against the *darkest 5%* of pixels in the background mean luminance test (computed server-side at upload, stored as `min_text_contrast`).
- Keyboard: full tab order; Enter/Space activate primaries.

## 10. Responsive

- Phone (≤600dp): 9:16 crop preferred; mobile variant served.
- Foldable (600–840dp): center-cropped 16:9.
- Tablet/web (≥840dp): full original variant served.
- Save-Data header → BlurHash only.

## 11. Theming

- Background layer composites under both Light, Dark, AMOLED, and Plus themes.
- AMOLED: scrim color is `#000000` for true-black hold-out; opacity range capped at 60% to avoid washing out background.
- Server accent color (when 09-customization ships) tints the focus reticle, not the background itself.
