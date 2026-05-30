# Reduced Motion Mode — Technical Requirements

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                         Flutter App                          │
│                                                                │
│  ┌────────────────────┐         ┌────────────────────────┐    │
│  │ MediaQuery         │────────>│ MotionPolicyProvider   │    │
│  │ .disableAnimations │         │  level = full|reduced  │    │
│  └────────────────────┘         │       |instant         │    │
│           │                     └────────────────────────┘    │
│           ▼                              │                    │
│  ┌────────────────────┐                  ▼                    │
│  │ User pref          │     ┌──────────────────────────┐      │
│  │ (manual override)  │     │ MotionAware widgets      │      │
│  └────────────────────┘     │  - PageTransition        │      │
│                             │  - AnimatedSwitcher      │      │
│                             │  - Lottie wrapper        │      │
│                             │  - GifAttachment         │      │
│                             └──────────────────────────┘      │
└──────────────────────────────────────────────────────────────┘
```

## 2. Components

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/reduced_motion/`
  - `application/motion_policy_provider.dart`
  - `application/motion_level.dart` (`enum MotionLevel { full, reduced, instant }`)
  - `data/preferences_datasource.dart`
  - `presentation/screens/reduced_motion_settings_screen.dart`
  - `presentation/widgets/motion_aware_switcher.dart`
  - `presentation/widgets/motion_aware_page_route.dart`
  - `presentation/widgets/static_celebration.dart` (replacement for confetti)
- **Cross-cutting edits:**
  - `mobile/lib/core/router/app_router.dart` — replace `PageRouteBuilder` with `MotionAwarePageRoute`
  - `mobile/lib/features/server_channels/.../typing_indicator.dart` — wobble disabled in reduced mode
  - `mobile/lib/features/server_channels/.../reactions_row.dart` — bounce disabled
  - `mobile/lib/features/voice/.../voice_join_animation.dart` — replaced with static
  - `mobile/lib/features/onboarding/.../welcome_animation.dart` — static fallback
  - `mobile/lib/features/server_channels/.../gif_attachment.dart` — auto-pause in reduced mode
  - `mobile/lib/features/notifications/.../snackbar.dart` — slide → fade
  - `mobile/lib/features/server/.../boost_celebration.dart` — sparkle disabled

### Backend (Go)
- No new endpoints. Pref stored in existing `accessibility_json`.

### Infra
- DB: extends existing JSONB (`reduced_motion_mode`, `auto_pause_gifs`).
- AI/Realtime/Storage: none.

## 3. API Contracts

### REST
```
GET    /api/v1/users/me/preferences         (existing)
PATCH  /api/v1/users/me/preferences         (existing)
```

### Payloads
```jsonc
{
  "accessibility": {
    "reduced_motion_mode": "auto",     // "off" | "auto" | "on"
    "auto_pause_gifs": true
  }
}
```

## 4. Permissions & Auth

Per-user prefs only.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Crossfade duration | 150 ms (or 0 ms if instant) |
| Transition latency reduction in reduced mode | ≥60% |
| Frame-time p95 | <8 ms in reduced; <16 ms in full |
| Memory overhead | <100 KB |
| Lottie playback CPU | 0 (pause + first-frame in reduced) |

## 6. Dependencies

- Existing: `theme_provider`, `lottie` package.
- New Flutter packages: none.

## 7. Observability

- Metrics:
  - `flicko_accessibility_reduced_motion_users_gauge`
  - `flicko_accessibility_reduced_motion_mode_total{mode}`
  - `flicko_accessibility_gif_autopause_users_gauge`
- Logs: pref-write logs only.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Some animation missed in retrofit | UX inconsistency | Lint rule that flags any `AnimationController` not subscribed to MotionPolicy |
| Crossfade drains attention (still movement) | Vestibular trigger | `instant` mode option for severe users |
| Lottie pause leaves frame at random | Visual oddity | Always render frame 0 |
| User pref toggled mid-route | Animation half-played | Snap to end on policy change |

## 9. MotionPolicy API

```dart
final motionPolicyProvider = StateNotifierProvider<MotionPolicy, MotionLevel>(...);

extension MotionAware on Duration {
  Duration adapted(MotionLevel level) => switch (level) {
    MotionLevel.full    => this,
    MotionLevel.reduced => this < const Duration(milliseconds: 150)
                              ? this
                              : const Duration(milliseconds: 150),
    MotionLevel.instant => Duration.zero,
  };
}
```

All new animations must use this extension.

## 10. Lint Rule

Custom analyzer rule `flicko_motion_policy` flags:
- `AnimationController(...)` constructed without an explicit duration argument
- `Tween<...>` chained with `CurvedAnimation` outside a `MotionAware` context
- Use of `Hero` without `MotionAwareHero`

## 11. Migration Path

- v0 → v1: ship core MotionPolicy + retrofit 18 animations called out by design QA.
- v1 → v2: third-party Lottie audit; user-facing "GIF playback" sub-pref.
