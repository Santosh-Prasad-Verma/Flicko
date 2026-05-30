# Gesture Controls - PRD

## 1. Summary

Flicko gains a coherent vocabulary of touch gestures that make common chat actions effortless: swipe-to-reply, long-press for the contextual menu, double-tap to react with a starred emoji, and three-finger swipe-down to undo. Gestures are discoverable via a one-time hint reel, customizable per user, and respectful of platform conventions and accessibility settings.

## 2. Problem

Power users live in chat. Tapping into menus to reply, react, or correct mistakes adds seconds and friction across hundreds of daily interactions. Today, Flicko relies almost entirely on visible buttons. Competitors with gesture vocabularies (iMessage, WhatsApp, Telegram) see significantly higher per-session message rates. We need a gesture set that:
- mimics platform conventions where they exist (so users don't have to learn anew),
- adds a small set of distinctive Flicko gestures (undo, react),
- never breaks accessibility,
- can be turned off completely.

## 3. Jobs to Be Done

- **JTBD-1** When I want to reply to a specific message, I want to swipe right on it instead of long-pressing and picking "Reply".
- **JTBD-2** When I made a typo, I want to three-finger swipe-down to undo my last send within 10 seconds.
- **JTBD-3** When I see a great message, I want to double-tap to react with my starred emoji.
- **JTBD-4** When I want to do something less common, I want long-press to reveal a tidy menu (react, copy, pin, edit, delete, share, report).
- **JTBD-5** When I configure my gestures, I want to swap which emoji double-tap fires.

## 4. Scope

### In Scope (v1)
- Swipe-right to reply (LTR locales) / swipe-left (RTL locales).
- Swipe-left to mark-read or dismiss notifications.
- Long-press contextual menu with adaptive items.
- Double-tap to react with user-starred emoji (default `:heart:`).
- Three-finger swipe-down to undo last send (within 10 s of send).
- Pull-to-refresh inertia tuned to mobile-first feel.
- Customization screen for swipe action, double-tap emoji, and toggling each gesture.
- One-time onboarding reel showing each gesture.
- Accessibility-equivalent buttons for every gesture.

### Out of Scope (v1)
- Mid-air or 3D Touch / Force Touch gestures.
- Custom gesture programming (e.g., user-defined swipes).
- Cross-device gesture preference sync. Local for v1.
- Voice trigger ("Hey Flicko, undo").
- Gesture recording / training (e.g., user draws a glyph).

## 5. Numeric Success Metrics

| Metric                                            | Target               | Source           |
|---------------------------------------------------|----------------------|------------------|
| Reply action via swipe (% of replies)             | 55%                  | analytics        |
| Reactions per active user per day                 | +30% vs baseline     | analytics        |
| Undo-send usage (% of sends with undo within 10s) | 4-6%                 | analytics        |
| Gesture-disabled user share                       | < 4% (i.e., most keep) | analytics      |

## 6. Competitive Landscape

| App          | Swipe reply | Double-tap react | Long-press menu | Undo send | Three-finger gesture |
|--------------|-------------|------------------|-----------------|-----------|----------------------|
| iMessage     | -           | Yes (Tapback)    | Yes             | -         | -                    |
| WhatsApp     | Yes         | Yes (recent)     | Yes             | Yes (server-side, undo for everyone) | - |
| Telegram     | Yes         | Yes              | Yes             | -         | -                    |
| Slack        | -           | -                | Yes             | -         | -                    |
| Discord      | -           | -                | Yes             | -         | -                    |
| **Flicko**   | **Yes**     | **Yes (starred emoji)** | **Yes (adaptive)** | **Yes (3-finger swipe)** | **Yes** |

The combination of three-finger undo and adaptive long-press is unique.

## 7. Non-Goals

- We will not deliberately diverge from platform gestures users already expect (e.g., pull-to-refresh).
- We will not enable gestures by default for users who turned on Reduce Motion + Switch Control + Voice Control simultaneously; we treat that as an accessibility profile and surface buttons explicitly.
- We will not make undo silently destroy server state if a recipient already saw the message.

## 8. Assumptions

- Average chat list has 30+ messages on screen, so multi-touch must not collide with single-touch reply/scroll.
- Three-finger gestures are reliable on phones with screens >= 5.5".
- Users who want gestures off are a small minority; we still make it easy.
- Most users keep default starred emoji `heart` but a sizable group changes it.

## 9. Constraints

- **A11y**: Every gesture has an equivalent button in the long-press menu. Reduce Motion replaces parallax with crossfade.
- **Privacy**: No additional data collection beyond bucketed event analytics.
- **Cost**: $0 third-party. Pure Flutter `GestureDetector`/`RawGestureDetector`.
- **Engineering**: 1 mobile engineer for the duration.

## 10. Risks

- **R1**: Three-finger swipe collides with iOS system text-edit gestures (cut/copy/paste). Mitigation: only register when not in a text field; bottom 30% of screen safe area excluded.
- **R2**: Swipe-to-reply conflicts with horizontal scroll within media galleries. Mitigation: bubble owns gesture; child galleries reject horizontal pans.
- **R3**: Long-press menu obscures the message in question. Mitigation: render the menu offset above/below; pointer position drives placement.
- **R4**: Users undo too eagerly and lose intent. Mitigation: 1-tap "redo" in confirmation toast.
