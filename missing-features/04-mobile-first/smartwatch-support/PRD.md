# Smartwatch Support - PRD

## 1. Summary

Bring Flicko to the wrist. WearOS and watchOS users see notifications, glance at unread channels, dictate quick voice replies, and react to messages without pulling out their phone. The watch is a peripheral; the phone remains the source of truth and handles all heavy lifting (transcription, sync, media). The watch surface is intentionally narrow: glance, react, reply, escape.

## 2. Problem

Mobile-first chat apps treat the watch as an afterthought. Notifications arrive but are read-only, replies require unlocking the phone, and there is no way to triage which conversations matter. Power users on the move (couriers, on-call engineers, parents juggling logistics) lose minutes per interaction. Competitors that *do* ship watch apps usually mirror the phone UI, which is unreadable on a 41 mm display.

We can do better by treating the watch as a one-thumb device with a 1.5 second attention budget per interaction.

## 3. Jobs to Be Done

- **JTBD-1** When a notification fires, I want to read the full message and the last 2 replies on my watch so I can decide whether to engage without unlocking my phone.
- **JTBD-2** When I cannot type, I want to dictate a voice reply or pick from smart suggestions so I can respond in under 5 seconds.
- **JTBD-3** When a thread blows up, I want to see unread counts per server at a glance so I can prioritize what to open later.
- **JTBD-4** When I get a wrong-channel notification, I want to mark it read or mute the channel from the watch so my wrist stops vibrating.
- **JTBD-5** When I open the Flicko complication, I want to see who is currently in voice with me, so I can rejoin in one tap.

## 4. Scope

### In Scope (v1)
- WearOS 4+ standalone module + watchOS 10+ extension.
- Notification mirroring with rich actions (reply, react, mark read, mute).
- Voice reply (handed off to phone for Whisper transcription, falls back to platform STT).
- Quick-react picker (6 emoji preset).
- Unread digest tile / complication.
- Active voice channel complication with rejoin tap.
- Deep link handoff: tapping the watch app body opens Flicko on the phone at the right channel.

### Out of Scope (v1)
- Watch-only photo capture or camera relay.
- Streaming voice/video on the watch.
- Standalone watch login (always paired).
- Apple Watch Ultra dual-tap gesture (deferred to v2).
- Stage channels, screen-share, gaming features.

## 5. Numeric Success Metrics

| Metric                                          | Target              | Source                       |
|-------------------------------------------------|---------------------|------------------------------|
| Watch DAU as % of mobile DAU                    | 8% by week 12       | analytics events             |
| Median time-to-reply via watch                  | 4.5 s end-to-end    | timing events on reply send  |
| Notification dismiss rate (watch vs phone-only) | -22%                | A/B against control cohort   |
| Crash-free sessions (watch app)                 | 99.4%               | Crashlytics                  |

## 6. Competitive Landscape

| App        | WearOS | watchOS | Voice reply | Reactions | Complications |
|------------|--------|---------|-------------|-----------|---------------|
| Discord    | No     | No      | -           | -         | -             |
| Slack      | Read-only | Read-only | No        | No        | Limited       |
| WhatsApp   | Yes    | No      | Yes         | No        | No            |
| Telegram   | Yes    | Yes     | Yes         | Limited   | Yes           |
| iMessage   | -      | Yes     | Yes         | Yes       | Yes           |
| **Flicko** | Yes    | Yes     | Yes (Whisper) | Yes (6) | Yes (digest + voice status) |

The combination of cross-platform parity, on-device Whisper handoff, and a voice-channel complication is unique to Flicko in v1.

## 7. Non-Goals

- We will not become a substitute for the phone app. If the user wants threads, search, or voice channels, the watch deep-links them into the phone.
- We will not implement custom watch faces. Only standard complications.
- We will not store messages on the watch beyond the last 30 received (working set).

## 8. Assumptions

- Users wearing a watch are paired and signed in on the phone. Standalone watch login is gated to v2.
- WearOS Tile and watchOS WidgetKit-on-watch APIs are stable on the targeted OS versions.
- Voice replies route through phone microphone when the watch is paired and Bluetooth is connected (battery-friendly).

## 9. Constraints

- **Budget**: $0 third-party. We use Apple's `WatchConnectivity` and Google's `Wearable Data Layer` (free, first-party).
- **Engineering**: 1 mobile engineer + 0.25 backend engineer.
- **Timeline**: 6 weeks to GA following the home-widgets release.

## 10. Risks

- **R1**: Apple's review of voice-reply payloads may flag privacy. Mitigation: we ship a prominent disclosure in onboarding.
- **R2**: WearOS device fragmentation makes UI testing painful. Mitigation: target only WearOS 4+ and run on Pixel Watch + Galaxy Watch 6 in CI.
- **R3**: Watch battery drain from frequent push wakeups. Mitigation: push coalescing (rate limit notifications to 1 per 30 s per channel).
