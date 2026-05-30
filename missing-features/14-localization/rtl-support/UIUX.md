# RTL Support — UI/UX Design

## 1. Design Principles

- **Logical, not physical:** every layout decision is "start/end", never "left/right".
- **Native conventions win:** RTL users expect mirrored chrome, but media controls (play, audio waveform progress) stay LTR per platform standards.
- **No half-mirroring:** an icon either flips or it doesn't — never mirror just one of a pair within a row.
- **Bidi over force:** trust the bidi engine; only override for code, URLs, phone numbers, or user-explicit per-message dir.
- **Test with pseudo-RTL:** every screen QA-checked in `xq-XR` before shipping ar/he/fa/ur.

## 2. Information Architecture

RTL is *not* a separate feature surface — it is a transparent layout mode. Triggered automatically when:
1. `LocaleProvider.locale` resolves to ar/he/fa/ur (or future RTL locales)
2. Or user toggles dev `Pseudo-RTL` flag

User-facing controls:
- `Settings → Language & Region → Show numbers in Arabic-Indic` (only for ar)
- `Settings → Developer → Pseudo-RTL` (debug builds only)
- Per-message long-press menu → `Force direction: LTR/RTL/Auto`

## 3. Screen Inventory

| # | Screen | RTL impact | States |
|---|--------|-----------|--------|
| All | every screen | layout mirrored, icons flipped per allowlist | identical to LTR |

## 4. Mirroring Reference

### Component-by-component

| Component | LTR | RTL | Notes |
|-----------|-----|-----|-------|
| App bar back arrow | ← left | → right | flipped via DirectionalIcon |
| Drawer | slides from left | slides from right | flip `Drawer` placement |
| Bottom nav order | Home, Servers, DMs, Profile | Profile, DMs, Servers, Home | reverses |
| Tab strip | LTR | RTL — last tab on left | natural via `Directionality` |
| Message bubble (mine) | right-aligned | left-aligned | start/end alignment |
| Message bubble (other) | left-aligned | right-aligned | start/end alignment |
| Reply swipe gesture | swipe right to reply | swipe left to reply | flipped |
| Send button (chat) | right end of input | left end of input | start/end |
| Read receipt checkmarks | right of bubble | left of bubble | start/end |
| Avatar in message | left of text | right of text | start/end |
| Voice channel speakers | left to right | right to left | flexibly arranged |
| Stage stage layout | speakers grouped left | speakers grouped right | mirror |
| Gaming hub leaderboard | rank left, score right | rank right, score left | start/end |
| Notification leading icon | left | right | start/end |
| Storage donut chart legend | side label right | side label left | flip |
| Settings list chevron | → | ← | DirectionalIcon |
| AI Aura wave animation | scrolls L→R | scrolls R→L | direction-aware |

### Wireframe — Chat in RTL (ar)

```
┌────────────────────────────────────────┐
│ ⋯              عنوان القناة         → │
├────────────────────────────────────────┤
│                                        │
│         [نص الرسالة الخاصة بي]   👤    │
│                                  ✓✓    │
│                                        │
│   👤  [Their reply text]               │
│                                        │
│         [مزج للنصوص اليوم!]      👤    │
│                                  ✓✓    │
│                                        │
├────────────────────────────────────────┤
│ ➤  [اكتب رسالة...]                +   │
└────────────────────────────────────────┘
```

### Wireframe — Voice channel in RTL

```
┌────────────────────────────────────────┐
│ ⋯           قناة صوتية #عام         → │
├────────────────────────────────────────┤
│                                        │
│    👤        👤        👤              │
│  أحمد     فاطمة      علي               │
│  🔊         🔊         🔊              │
│                                        │
├────────────────────────────────────────┤
│  📞     ✋     🎤     🎧               │
│ مغادرة  رفع  كتم   صم                  │
└────────────────────────────────────────┘
```

## 5. Component Specs

### `DirectionalIcon`
- Props: `IconData ltr, IconData? rtl, double size, Color? color`
- If `rtl` provided, use it; else `Transform.scale(-1, 1)` mirror of `ltr`
- Falls back to `Icon(ltr)` if widget Directionality is LTR

### `BidiText`
- Detects per-string direction via first-strong char
- Wraps in `Directionality` for that scope
- Useful for mixed-content lists (e.g. server names from many locales)

### `MirroredSlideTransition`
- Wraps `SlideTransition` and inverts `Tween<Offset>` X-axis when RTL
- Used for drawers, sheets, dismissal animations

### `DirectionalSwipeDetector`
- Custom `GestureDetector` wrapper
- Maps `onSwipeStart`/`onSwipeEnd` semantically
- Reply-swipe direction set automatically

## 6. Empty / Error / Loading

- Same as LTR — only difference is start/end alignment.
- Empty-state illustration: review for cultural neutrality (no left-pointing arrows in the artwork).
- Loading shimmer: gradient direction follows `Directionality.of(context)`.

## 7. Copy

- All copy from `multi-language-50` ARB files; this feature does not introduce new strings.
- Two new strings:
  - `settings.use_arabic_indic_digits` — "Use Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩)"
  - `message.force_direction.dialog_title` — "Force text direction"
- Voice: same as global copy guidelines (friendly, concise, second-person).

## 8. Motion

- Page transitions in RTL: shared-axis X-flipped (entering page slides in from the left, exits to the right) — natural with `Directionality`.
- Inline reveal: same easing, same duration; only start/end positions change.
- Reduced-motion: still applies — crossfade replaces slide.

## 9. Accessibility

- Screen reader gestures stay logical (single-finger swipe right always = "next" regardless of locale per Apple/Google).
- Semantics labels remain unchanged — accessibility tree is direction-agnostic.
- Color contrast and tap targets identical.
- VoiceOver/TalkBack tested with each launch RTL locale before GA.

## 10. Responsive

- All breakpoints behave identically — they are layout, not direction. The mirror just reflects the same arrangement.
- Web: ensure `<html dir="rtl">` set on locale change.
- Foldable in book mode: spread reads right-to-left in ar.

## 11. Theming

- Light/Dark/AMOLED unaffected.
- Server accent color usage unaffected.
- Font fallback: Noto Naskh Arabic for ar; Noto Sans Hebrew for he; Noto Sans Arabic for fa, ur (Persian/Urdu use Arabic-script). Bundled in `mobile/fonts/`.

## 12. Pseudo-RTL Mode (xq-XR)

- Activated from dev menu only.
- Layout flips, but text remains English (not transformed like xq-XQ).
- Useful for engineers who don't read ar/he/fa/ur — they can still spot mirroring bugs.
- Banner shown at the top: "Pseudo-RTL — for testing only".

## 13. Per-Message Direction Override (Power-User)

- Long-press a message → bottom sheet → "Direction" → choose Auto / LTR / RTL.
- Persisted per message; backend stores in `messages.direction_override` (nullable).
- Only the message author can override their own message direction.
- Useful for: copy-pasting English code into a Hebrew DM and wanting it to render LTR.
