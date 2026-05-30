# Screen Capture Protection — Product Requirements

> **One-line:** Block screenshots and detect screen recording on sensitive channels.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** M
> **Priority:** P1

## 1. Problem

Disappearing messages and E2EE voice both have a glaring leak: the receiving device can take a screenshot or record the screen. There is no perfect defense, but the OS gives us two tools — `FLAG_SECURE` on Android (blocks screenshot, blacks out screen recording, hides from app switcher) and `UIScreen.captureDidChangeNotification` on iOS (detects recording is active and lets us blank the UI). Discord does not expose either control to community members.

Real evidence:
- Banking apps, Signal, and Telegram have used these flags for years; users expect them to exist when content is sensitive.
- Subpoenas and screen-capture-leaks of Discord DMs are routine in news cycles.
- Mods of mental-health and abuse-recovery servers in particular ask for "make this channel un-screenshottable."

The pain: any sensitive thread is one swipe away from being permanently captured by anyone in the room.

## 2. Users & Use Cases

- **Primary persona:** Mods of sensitive servers (support, advocacy, legal) who want to mark certain channels "no screenshot."
- **Secondary personas:** Individuals in DMs who want screenshot protection on a per-DM basis; users sharing time-sensitive credentials.
- **Top 3 jobs-to-be-done:**
  1. As a mod, I want to flag a channel as no-screenshot, so that members understand they are entering a private space.
  2. As a DM participant, I want my chat hidden from screen recording, so that nothing leaks to the cloud via the recipient's recording app.
  3. As a user, I want to know when the other side is recording, so that I can mute or leave.

## 3. Goals & Non-Goals

**Goals**
- Per-channel "screen-capture-protection" toggle, mod-controlled.
- Per-DM "screen-capture-protection" toggle, both participants must agree.
- Android: enable `FLAG_SECURE` on activities showing protected content.
- iOS: detect `UIScreen.isCaptured` and overlay a black scrim while recording is active. Show notification banner "Screen recording active."
- Optional: notify the other side ("Alex started recording the screen") on iOS.
- Server-side label so other clients know to render the protected indicator.

**Non-Goals (out of scope for v1)**
- Watermarking (a separate feature in roadmap).
- Web client (no native flag; document limitation).
- Stopping camera-of-screen attacks (impossible).
- DRM-style hardware enforcement.

## 4. Scope (v1)

- [ ] `flutter_windowmanager` integration for `FLAG_SECURE` on protected screens.
- [ ] iOS native channel for `UIScreen.captureDidChangeNotification`.
- [ ] Per-channel mod setting `screen_capture_protected`.
- [ ] Per-DM toggle requiring both-party consent.
- [ ] In-thread badge "Screen capture protected."
- [ ] iOS-side: black-scrim overlay when screen recording active; banner.
- [ ] Optional: realtime event "user is recording" to other participants.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Channels enabling protection | ≥3% sensitive servers within 90d | server_settings query |
| Screenshot-block events (Android) | tracked | `flutter_windowmanager` event |
| Recording-detection events (iOS) | tracked | analytics |
| User confidence rating | ≥4.0/5 | NPS survey |

## 6. Open Questions / Risks

- **Risk: false sense of security.** Users may think the feature stops camera-of-screen attacks. Mitigation: in-product copy explicitly says "phone camera can still photograph the screen."
- **Risk: iOS only detects, doesn't block.** Document this asymmetry clearly.
- **Risk: web client.** No native equivalent. UI shows "Web client cannot enforce screen-capture protection — content blocked here."
- **Open: should we hide protected channels in the app switcher entirely?** `FLAG_SECURE` does that on Android. On iOS, snapshot-blur is configurable.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None | Native protection |
| Signal | Always on (configurable) | Per-channel granularity |
| Snapchat | Recording-detection notification | Same UX, in a community app |
| Telegram | Per-chat secret | Per-channel inside servers |

## 8. Rollout

- Internal dogfood → 5% beta → 25% → GA.
- Kill switch: `feature.screen_capture_protection.enabled`.
- Per-channel + per-DM granular flags.
