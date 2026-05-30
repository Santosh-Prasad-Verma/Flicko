# Screen Reader Full Support — Technical Requirements

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Mobile (Flutter) — Primary                   │
│                                                                   │
│  ┌──────────────┐    ┌────────────────┐    ┌─────────────────┐  │
│  │ AppRoot      │───>│ A11yScope      │───>│ Page Scaffolds  │  │
│  │ (Shortcuts)  │    │ (provider)     │    │ (Semantics tree)│  │
│  └──────────────┘    └────────────────┘    └─────────────────┘  │
│         │                    │                       │           │
│         ▼                    ▼                       ▼           │
│  ┌──────────────┐    ┌────────────────┐    ┌─────────────────┐  │
│  │ Focus engine │    │ LiveRegion bus │    │ Verbose-mode    │  │
│  │ (FocusScope) │    │ (StreamController)│  │ pref provider  │  │
│  └──────────────┘    └────────────────┘    └─────────────────┘  │
│                                │                                  │
│                                ▼                                  │
│                       ┌────────────────────┐                      │
│                       │ SemanticsService   │                      │
│                       │ .announce(...)     │                      │
│                       └────────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                  Platform Screen Reader (TalkBack / VoiceOver / NVDA)
```

A separate "Semantics audit harness" runs at app boot in debug builds and walks the rendered tree, reporting any interactive widget without `excludeSemantics: true` or a non-empty label.

## 2. Components

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/screen_reader/`
  - `application/screen_reader_provider.dart` — Riverpod provider exposing `verboseAnnouncements`, `announce(String, {assertive})`, `landmark(SemanticsRole)`.
  - `application/live_region_controller.dart` — `StreamController<String>` plumbed into a top-level `Semantics(liveRegion: true, child: Offstage())` to satisfy reader engines that want a single anchor node.
  - `presentation/widgets/landmark_scaffold.dart` — wraps `Scaffold` with `Semantics(container: true, role: SemanticsRole.banner | navigation | main)`.
  - `presentation/widgets/a11y_icon_button.dart` — drop-in replacement for `IconButton` that requires a `tooltip` and forwards it as `semanticLabel`.
  - `presentation/widgets/announce_on_change.dart` — listens to a `ValueListenable<String>` and pushes to `LiveRegion`.
- **Cross-cutting edits to existing widgets** (Semantics retrofit list — 25 hot widgets):
  1. `mobile/lib/features/server_channels/.../message_bubble.dart`
  2. `mobile/lib/features/server_channels/.../message_input.dart`
  3. `mobile/lib/features/server_channels/.../channel_list_item.dart`
  4. `mobile/lib/features/server_channels/.../voice_tile.dart`
  5. `mobile/lib/features/server_channels/.../member_list_item.dart`
  6. `mobile/lib/features/server_channels/.../typing_indicator.dart`
  7. `mobile/lib/features/server_channels/.../reactions_row.dart`
  8. `mobile/lib/features/server_channels/.../message_attachment.dart`
  9. `mobile/lib/features/server_channels/.../mention_chip.dart`
  10. `mobile/lib/features/server/presentation/widgets/server_list_tile.dart`
  11. `mobile/lib/features/home/presentation/home_navigation.dart`
  12. `mobile/lib/features/notifications/.../notification_tile.dart`
  13. `mobile/lib/features/direct_messages/.../dm_thread_tile.dart`
  14. `mobile/lib/features/voice/.../voice_controls_bar.dart`
  15. `mobile/lib/features/calling/.../incoming_call_sheet.dart`
  16. `mobile/lib/features/profile/.../profile_action_button.dart`
  17. `mobile/lib/features/settings/.../settings_tile.dart`
  18. `mobile/lib/features/auth/.../oauth_button.dart`
  19. `mobile/lib/features/onboarding/.../onboarding_step.dart`
  20. `mobile/lib/features/search/.../search_result_item.dart`
  21. `mobile/lib/features/store/.../store_card.dart`
  22. `mobile/lib/features/gaming/.../game_card.dart`
  23. `mobile/lib/features/ai_assistant/.../aura_message_bubble.dart`
  24. `mobile/lib/features/shared/presentation/widgets/snackbar.dart`
  25. `mobile/lib/features/shared/presentation/widgets/bottom_sheet.dart`

### Backend (Go) — minimal
- No new service. Telemetry receiver only:
  - `backend/internal/handlers/accessibility/telemetry_handler.go` accepts `POST /api/v1/accessibility/telemetry` with `{event, surface, missing_semantic_count, assistive_tech}`.
  - Stored in existing `analytics_events` table (no new schema).

### Infra
- DB: no new tables (preference stored in existing `user_preferences.accessibility_json`).
- Realtime: none (announcements are local).
- Cache: none.
- AI: none.
- Queue: none.

## 3. API Contracts

### REST
```
POST   /api/v1/accessibility/telemetry      enqueue analytics event
GET    /api/v1/users/me/preferences         (existing) returns accessibility_json
PATCH  /api/v1/users/me/preferences         (existing) writes verbose_announcements
```

### Payloads
```jsonc
// PATCH preferences
{
  "accessibility": {
    "verbose_announcements": true,
    "live_region_mode": "polite",       // "polite" | "assertive" | "off"
    "landmark_navigation": true
  }
}

// telemetry event
{
  "event": "semantics_missing",
  "surface": "MessageBubble",
  "missing_semantic_count": 1,
  "assistive_tech": "talkback"
}
```

## 4. Permissions & Auth

- All new endpoints reuse existing JWT auth; no new scopes needed.
- The verbose preference is per-user, written through the existing preferences service which already enforces `user_id = auth.uid()` RLS.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Extra build time per screen due to Semantics | <5 ms p95 |
| Live-region announcement latency | <250 ms from message arrival |
| Memory overhead | <2 MB |
| Telemetry payload size | <1 KB |
| Preference write p99 | <120 ms |
| Availability of telemetry endpoint | 99.5% (best-effort) |

## 6. Dependencies

- Existing services: `user_preferences_service`, `analytics_pipeline`.
- New Flutter packages: `flutter_accessibility_service` (^0.0.7) — debug-only, used by audit harness; gated behind `kDebugMode`.
- External APIs: none.

## 7. Observability

- Metrics:
  - `flicko_accessibility_announcements_total{mode="polite|assertive"}`
  - `flicko_accessibility_semantics_missing_total{surface}`
  - `flicko_accessibility_verbose_users_gauge`
- Logs: structured logs `accessibility.semantics_missing` to Sentry tag.
- Traces: not required (client-only feature).
- Dashboards: Grafana board `accessibility-overview` with adoption + missing-semantics.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| TalkBack ignores live region | Messages not announced | Fallback: `SemanticsService.announce()` direct call when stream emits |
| `Semantics` widget tree explosion (>10k nodes) | Frame skip | `MergeSemantics` on long lists; virtualised list semantics |
| Verbose mode set on but reader not enabled | Wasted render work | Detect via `MediaQuery.of(context).accessibleNavigation` |
| User preference write fails offline | Stale verbose state | Local cache, sync on reconnect |
| Localized announcement string missing | Falls back to English | Translator-marked strings; CI check for missing keys |

## 9. Testing Strategy

- `flutter_test` golden semantics tree tests for the 25 widgets.
- Patrol integration test: spin TalkBack on emulator, navigate chat → assert announcements include "new message from <name>".
- Manual quarterly audit by external a11y consultant (e.g., Fable).
- axe-flutter run in CI on PR.

## 10. WCAG 2.1 AA Mapping

| SC | How we satisfy |
|----|----------------|
| 1.1.1 Non-text Content | All icons get `semanticLabel`, decorative images marked `excludeSemantics` |
| 1.3.1 Info and Relationships | Landmark roles, `MergeSemantics` for grouped controls |
| 2.1.1 Keyboard | (covered by `full-keyboard-nav`) |
| 2.4.3 Focus Order | Custom `FocusTraversalPolicy` for chat → input → channel list |
| 2.4.6 Headings and Labels | Channel header marked `header: true` |
| 3.2.4 Consistent Identification | Same icon = same label across the app (icon → label registry) |
| 4.1.2 Name, Role, Value | All custom widgets implement `SemanticsConfiguration` |
| 4.1.3 Status Messages | Live region for chat + toast |

## 11. Migration Path

- v0 → v1: ship behind flag, default ON, monitor `semantics_missing_total` for 1 week.
- v1 → v2 (post-launch): add `aria-describedby`-style supplementary info for power users.
