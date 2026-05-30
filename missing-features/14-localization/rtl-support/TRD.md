# RTL Support — Technical Requirements

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Flutter App                            │
│                                                                 │
│   LocaleProvider ──▶ TextDirection (rtl/ltr)                    │
│                              │                                  │
│                              ▼                                  │
│                  MaterialApp.builder                            │
│             ┌────────────────────────────┐                      │
│             │ Directionality(            │                      │
│             │   textDirection: dir,      │                      │
│             │   child: ...               │                      │
│             │ )                          │                      │
│             └────────────────────────────┘                      │
│                              │                                  │
│         ┌────────────────────┼─────────────────────┐            │
│         ▼                    ▼                     ▼            │
│   AlignmentDirectional  EdgeInsetsDirectional  PositionedDirectional
│         │                    │                     │            │
│         └─────── DirectionalIcon (mirror or static) ─────────── │
│                              │                                  │
│                  Bidi-aware Text widgets                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ POST /api/v1/messages
┌─────────────────────────────────────────────────────────────────┐
│                        Go Backend                               │
│                                                                 │
│   bidi.DetectDirection(text) ──▶ messages.direction             │
│   profile.preferred_lang ── influences mail dir attribute       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/i18n/rtl-support/service.go`
  - `DetectDirection(text string) string` — returns `"ltr"|"rtl"|"auto"`
  - Uses `golang.org/x/text/unicode/bidi` for first-strong detection
- **Handlers:** `messages_handler.go` calls `DetectDirection` on insert; persists `direction` column
- **Model:** `Message.Direction` field added
- **Mail-gateway:** template renderer reads `recipient.preferred_lang` → looks up `i18n_locales.rtl` → injects `dir` attribute

### Mobile (Flutter)
- **Cross-cutting folder:** `mobile/lib/core/rtl/`
  - `directional_icon.dart` — wrapper that mirrors specific icons in RTL
  - `directional_extensions.dart` — context.dirAware() helpers
  - `bidi_text.dart` — Text widget that auto-detects direction per string
  - `pseudo_rtl.dart` — dev-only mirror without translation
- **App root:** `mobile/lib/app.dart` — sets `MaterialApp.localizationsDelegates` and ensures `Directionality` propagates

### Lint
- Custom Dart analyzer plugin `tools/lints/rtl_safe/`
  - Rule 1: ban `EdgeInsets.only(left:..., right:...)` outside `core/rtl/` allowlist
  - Rule 2: ban `Alignment.centerLeft|centerRight` — must use AlignmentDirectional
  - Rule 3: ban `Icons.arrow_back|arrow_forward` — must use `DirectionalIcon.back|forward`
  - Rule 4: warn on raw `Transform.translate(Offset(dx,...))` if dx > 0 — likely needs flipping

## 3. API Contracts

No new public APIs. Existing `messages` endpoint gains a column:

```jsonc
// POST /api/v1/messages
{
  "channel_id": "...",
  "text": "Hello مرحبا",
  "direction": "auto"  // server detects if "auto"
}

// Response includes resolved direction
{ "id": "...", "text": "...", "direction": "rtl" }
```

## 4. Permissions & Auth

No new permissions. RTL is a rendering concern, not a permission concern.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Bidi detect latency | <0.05 ms per message (in-process) |
| Layout perf delta vs LTR | <1 frame (16ms) |
| Golden test count | ≥25 (5 screens × 5 RTL locales/pseudo) |
| App size impact | 0 KB (no extra fonts; Noto already covers ar/he/fa/ur) |
| Crash rate RTL vs LTR | parity (delta ≤0.1%) |

## 6. Dependencies

### Existing
- `multi-language-50` (locale codes, flag `rtl` on `i18n_locales`)
- `mobile/lib/core/i18n/locale_provider.dart`

### New libraries
- Go: `golang.org/x/text/unicode/bidi` (already a transitive dep, pin v0.16.0)
- Flutter: nothing — `Directionality` is core SDK
- Dev: custom analyzer plugin (no external pkg)

### External
- None.

## 7. Observability

- Metrics:
  - `flicko_rtl_messages_total{dir}` — counter
  - `flicko_rtl_layout_overflow_total{screen}` — counter (from Flutter error reporter)
- Logs: Sentry breadcrumb when bidi detection returns ambiguous
- Traces: not required (sub-millisecond)
- Dashboards: panel on i18n Grafana board — % messages by dir per locale

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Custom widget ignores Directionality | screen looks broken | wrap in scoped `Directionality` fallback |
| Bidi engine misclassifies | user-facing weirdness | manual override (long-press → set dir) |
| 3rd-party SDK rendering breaks (e.g. video player overlay) | overlapping controls | wrap in LTR Directionality |
| Icon flipped that shouldn't be (e.g. logo) | brand issue | strict allowlist of mirror-eligible icons |
| Phone number reordered | confusing | wrap PII formatters in `Directionality.ltr` |

## 9. Implementation Specifics

### `DirectionalIcon` widget
```dart
class DirectionalIcon extends StatelessWidget {
  final IconData ltr;
  final IconData? rtl; // if null, mirror via Transform
  const DirectionalIcon({required this.ltr, this.rtl});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    if (!isRtl) return Icon(ltr);
    if (rtl != null) return Icon(rtl!);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
      child: Icon(ltr),
    );
  }
}
```

### Mirror allowlist (icon names)
```
arrow_back, arrow_forward, chevron_left, chevron_right,
keyboard_arrow_left, keyboard_arrow_right, navigate_before, navigate_next,
send, reply, redo, undo, double_arrow, trending_flat, exit_to_app, login,
arrow_outward, swipe_left, swipe_right, format_indent_increase, format_indent_decrease
```

### Do-not-mirror list (icon names)
```
play_arrow, fast_forward, fast_rewind (audio), volume_*,
brand_logos, lock, key, search, globe, check, close, more_vert,
help, info, settings_*, person_*, group_*
```

### `BidiText` widget
```dart
class BidiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const BidiText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    final dir = _detectDirection(text) ?? Directionality.of(context);
    return Directionality(
      textDirection: dir,
      child: Text(text, style: style),
    );
  }
}
```

## 10. Testing Strategy

- Golden tests for 5 critical screens × 5 dir-relevant locales (ar, he, fa, ur, xq-XR pseudo) = 25 goldens.
- Widget tests for `DirectionalIcon` with both directions.
- Property test for `DetectDirection`: invariants on first-strong character mappings.
- Manual testing matrix: RTL × phone/tablet × portrait/landscape × light/dark = 16 manual passes per release.
- E2E (Maestro): full chat flow in ar — send, reply, react, swipe-back-out.
- Accessibility: VoiceOver in ar; verify swipe gestures don't get flipped (gestures stay logical regardless of locale per Apple/Google guidelines for screen reader navigation).
