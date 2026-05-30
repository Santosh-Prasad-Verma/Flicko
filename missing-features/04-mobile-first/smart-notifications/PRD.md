# Smart Notifications - PRD

## 1. Summary

Flicko users get too many notifications. We replace the default "buzz on every message" model with an on-device priority classifier that ranks each incoming notification (`urgent`, `relevant`, `social`, `noise`) and only buzzes the wrist or wakes the screen for the top tiers. Classification runs entirely on the device using a small LLM (Gemini Nano on Android via AICore, Phi-3-mini via Mediapipe / Core ML on iOS), so no message content ever leaves the phone for ranking.

## 2. Problem

Group chat is noisy. Server channels with 500 members generate hundreds of notifications a day. Users can either (a) leave defaults on and drown in interruptions, or (b) mute everything and miss the messages that matter. Per our analytics, 41% of mobile DAU have at least one over-muted server, and 18% have global notifications disabled - which makes the app effectively dead for them.

Existing solutions (keyword highlights, mention-only, mute) require manual configuration that nobody does. We need a default that just works.

## 3. Jobs to Be Done

- **JTBD-1** When my best friend DMs me, I want a buzz immediately, even if my server has noise muted.
- **JTBD-2** When 50 people are arguing in #random, I want one summary buzz an hour, not 50.
- **JTBD-3** When someone asks an actual question that I can answer, I want to be pinged faster than for memes.
- **JTBD-4** When my on-call channel posts an alert, I want it to bypass DND and ring.
- **JTBD-5** When I have a quiet wind-down hour, I want only urgent items through, with the rest queued for morning.

## 4. Scope

### In Scope (v1)
- On-device priority classifier (4 tiers: urgent, relevant, social, noise).
- Per-channel and per-server overrides.
- Quiet hours with priority-only delivery.
- Daily digest at user-chosen times for `noise` and `social`.
- "Why this notification" explainer screen.
- User correction loop ("not urgent" feedback) that adjusts personal weights.
- Bypass-DND for `urgent` (with explicit consent).

### Out of Scope (v1)
- Cloud-side classification.
- Full personalization model retraining (we use lightweight on-device adapters only).
- Cross-device sync of personal weights (deferred to v2).
- Voice message classification (handled by voice-message-transcription feature).
- Notification action buttons (kept default for now).

## 5. Numeric Success Metrics

| Metric                                          | Target           | Source                          |
|-------------------------------------------------|------------------|---------------------------------|
| Average notifications per DAU per day           | -45% vs baseline | analytics events                |
| User-reported "too many notifications" rate     | -60%             | quarterly NPS survey            |
| False-negative rate (missed urgent flagged later) | < 1.2%         | user "should have buzzed" feedback |
| Classifier latency p95 on midrange devices      | < 180 ms          | device telemetry                |

## 6. Competitive Landscape

| App         | Smart prioritization | On-device | DND bypass | Daily digest | Feedback loop |
|-------------|----------------------|-----------|------------|--------------|---------------|
| Discord     | Keyword highlights   | -         | No         | No           | No            |
| Slack       | Notification keywords + scheduled summaries | No (server-side) | Yes (manual) | Yes | Limited |
| Gmail       | Priority Inbox       | No        | -          | No           | Yes (over years) |
| iOS 18 Mail | Apple Intelligence (server hybrid) | Hybrid | Yes | Yes | Implicit |
| **Flicko**  | LLM tiered priorities | **Yes (Gemini Nano / Phi-3-mini)** | Yes (opt-in) | Yes | Yes (per-message thumbs) |

The combination of fully on-device classification, per-message feedback loop, and digest delivery is differentiating.

## 7. Non-Goals

- We will not run a server-side classifier. Privacy is the primary value prop.
- We will not provide a "promo / commercial" tier; Flicko is not email.
- We will not fight the user's chosen channel mute settings; classification only affects unmuted channels.

## 8. Assumptions

- AICore (Android 14+) and Core ML (iOS 17+) are available on a meaningful share of devices. Older devices fall back to a heuristic ranker (rules + keywords), which we acknowledge will be less accurate.
- Users are willing to give one or two "thumbs" per week to refine personal weights.
- Notification payloads are small (<= 4 KB) so classification is fast.

## 9. Constraints

- **Privacy**: No message body leaves the device for classification. This is a hard constraint enforced by code review.
- **Battery**: Classifier must run within 200 ms p95 and <= 0.5% additional daily battery.
- **Cost**: $0 third-party. Models ship with the app or are downloaded once via the OS.
- **Engineering**: 1 mobile engineer + 0.25 ML engineer for prompt + eval.

## 10. Risks

- **R1**: Misclassification of urgent message as noise. Mitigation: conservative thresholds + user feedback loop + on-call channel override.
- **R2**: Model size bloats app binary. Mitigation: download model on first launch, cache in app dir, use OS-provided runtime where available.
- **R3**: Performance regressions on midrange devices. Mitigation: heuristic fallback, automatic degradation when classifier latency > 250 ms p95 over 50 samples.
- **R4**: User trust ("why didn't I get pinged?"). Mitigation: per-message explainer with the prompt + tier + override CTA.
