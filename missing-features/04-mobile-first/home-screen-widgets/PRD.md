# Home Screen Widgets — Product Requirements

> **One-line:** Native iOS/Android home-screen widgets surfacing unread, quick-reply, recent server, friend status.
> **Status:** Missing — to build
> **Category:** 04-mobile-first
> **Effort:** L
> **Priority:** P1

## 1. Problem

Discord has zero meaningful home-screen widgets on iOS and Android. The official Discord iOS widget shipped in 2021 was removed in 2023 due to maintenance burden, and the Android widget was never released. Users repeatedly ask for "at-a-glance unread counts" and "quick reply from home screen" on r/discordapp (top 50 of 2024 feature-request threads). Power users keep Discord pinned to the dock and tap-then-wait-1.5s-cold-start just to see if a friend is online. That cold start is a churn vector — every extra second is a 6% drop in re-open probability per Mixpanel benchmarks.

Flicko exploits this by being widget-first. We expose four high-signal widget faces that read directly from the local Riverpod cache (no network on render) and write back through the existing app process via background URLSession / WorkManager.

## 2. Users & Use Cases

- **Primary persona:** mobile-heavy Flicko user (18-30, opens 20+ times/day) who keeps multiple servers and wants ambient awareness without launching the app.
- **Secondary personas:** community moderators (need DM/mention pulse), casual users (just want friend online indicator).
- **Top 3 jobs-to-be-done:**
  1. As a heavy user, I want to see unread mention count on my home screen, so that I never miss a callout.
  2. As a friend-circle user, I want a one-tap reply field for my last DM thread, so that I can respond without launching the app.
  3. As a server lurker, I want to see which friends are online right now, so that I can decide whether to jump in.

## 3. Goals & Non-Goals

**Goals**
- Four widget faces: Unread Pulse, Quick Reply, Recent Server, Friend Status.
- Each face available in S (2x2), M (4x2), L (4x4) where the platform allows.
- Refresh budget: <=15 minutes background, instant on app foreground.
- Battery delta vs no-widget: <=1.2% over 24h on iPhone 12 / Pixel 6.
- Tap on any widget cell deep-links to the precise screen (channel, DM thread, friend profile).

**Non-Goals (out of scope for v1)**
- Interactive scrolling inside the widget (iOS WidgetKit forbids it; we will not fight the platform).
- Voice/video preview in widget.
- Lock screen widgets on iOS (separate effort tracked in `04-mobile-first/lock-screen-glance`).
- Live Activities / Dynamic Island (separate spec).
- StandBy mode customization on iOS 17+.

## 4. Scope (v1)

- [ ] Unread Pulse widget (S/M/L) — total unread + per-server breakdown
- [ ] Quick Reply widget (M only) — last DM thread + tap-to-reply that opens compose pre-filled
- [ ] Recent Server widget (S/M) — last 4 servers iconography with unread dot
- [ ] Friend Status widget (M/L) — top 6 friends, presence dot, status text, tap-to-DM
- [ ] Widget configuration screen in app settings ("which servers count toward unread", "which friends to show")
- [ ] Background refresh via Flutter `home_widget` + native side
- [ ] Deep link routing through existing `app_router.dart`
- [ ] iOS Widget Gallery preview screenshots (3 per widget)
- [ ] Android `AppWidgetProvider` previews
- [ ] Migration `142_widget_configs.up.sql`

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% mobile DAU with >=1 widget pinned) | 22% within 60d | PostHog `widget_pinned` event from app |
| Cold-start reduction | -35% home-screen-to-content vs no-widget cohort | RUM trace |
| Battery delta | <=1.2% over 24h | Xcode Energy Log + Android Battery Historian |
| Crash-free sessions for widget extension | 99.7% | Sentry split by `dist` channel |
| Widget tap-through CTR | >=18% per render | PostHog `widget_tap` / `widget_render` |

## 6. Open Questions / Risks

- iOS WidgetKit caps timeline entries at ~70/day per widget — we will batch refresh on app foreground rather than burn timeline budget.
- Android Glance is still 1.x and has known issues with text wrapping on Samsung One UI 5+ — fallback to RemoteViews if Glance crashes twice in 24h (telemetry-driven).
- Server-side push for widget refresh requires a new lightweight `widget_ping` Centrifugo channel — adds ~3% to existing realtime fanout cost.
- Privacy: showing DM previews on lock-screen-adjacent surfaces could violate user expectations — gated behind explicit opt-in toggle.
- Friend presence pulled every 15m means widget can show "online" up to 15m stale; mitigate with last-seen timestamp in the widget face.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | iOS widget retired 2023, Android never had one | Full multi-face widget suite from launch |
| Slack | Single "unread" iOS widget, no Android | Per-server unread + quick reply |
| WhatsApp | Last-message Android widget, no iOS | Multi-platform parity, server context |
| Telegram | Chat list widget on both platforms | Friend presence + quick reply combined |
| Revolt | None | Native widgets entirely |

## 8. Rollout

- Internal dogfood (TestFlight + internal Play track) -> 1% public beta -> 10% -> 50% -> GA over 14 days.
- Kill switch flag: `feature.home_screen_widgets.enabled` checked at app cold start; if disabled, widgets show "Open Flicko" placeholder.
- Per-platform rollout decoupled — iOS may ship a week ahead while Android Glance issue is debugged.
- Failure rate >2% in any 1h window auto-disables flag and pages on-call.
