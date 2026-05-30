# Message Themes — Product Requirements

> **One-line:** Per-user chat bubble styles — rounded, square, classic; pick your density.
> **Status:** Missing — to build
> **Category:** 09-customization
> **Effort:** S
> **Priority:** P2

## 1. Problem

Discord renders chat as flat lines with avatars; iMessage renders bubbles; Telegram lets you pick. Users frequently say Flicko/Discord chat looks "boring" compared to iMessage or WhatsApp. Customizing bubble shape, tail, and density is a low-cost personalization win that meaningfully changes the feel of the app.

Some users prefer dense single-line layout for productivity (Slack-like); others want tall, rounded "messenger" bubbles for vibe. Currently we offer none of this.

## 2. Users & Use Cases

- **Primary persona:** "Sky" — coming from iMessage, wants rounded bubbles with tails on their own messages.
- **Secondary personas:** productivity users wanting compact density; aesthetic users matching their theme.
- **Top 3 jobs-to-be-done:**
  1. As a user, I want bubbly chat, so it feels personal.
  2. As a user, I want compact density, so I can scan more on screen.
  3. As a user, I want my style to follow me across servers and devices, so it feels like *mine*.

## 3. Goals & Non-Goals

**Goals**
- 3 bubble shapes: rounded, square, classic (no bubble, just text).
- Tail vs no-tail toggle.
- 3 density steps: compact, cozy, comfy.
- Per-user setting; syncs across devices.
- Preview pane before commit.

**Non-Goals (out of scope for v1)**
- Per-server forced bubble style.
- Per-channel style.
- Custom bubble colors (use theme engine).
- Animated bubbles, gradients, fluid morphing — leave to themes/ later.

## 4. Scope (v1)

- [ ] Riverpod `messageThemeProvider` with shape, tail, density.
- [ ] `chat_bubble.dart` reads provider and applies.
- [ ] Settings screen "Chat appearance" with live preview.
- [ ] Persist to backend `message_theme_settings`.
- [ ] L10n keys for labels.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU non-default) | 22% within 30d | PostHog `message_theme.changed` |
| Time-to-apply | <60ms | client metric |
| Frame budget regression | 0 | golden + perf |
| Cost per user | $0 | infra |

## 6. Open Questions / Risks

- Does compact density risk breaking attachment/reaction layouts? Yes — must test gold images of all attachment types.
- Square + no-tail looks like Slack; risk of being seen as derivative? Acceptable; users want it.
- Voice messages render uniformly across shapes — agreed.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Two density options; no shape | Shape + tail toggle |
| Slack | Compact/cozy; no shape | Same plus shapes |
| Telegram | Bubble shape | Match + density |
| iMessage | Bubble fixed | Choice |

## 8. Rollout

- Internal dogfood → 10% beta → GA.
- Flag: `feature.message_themes.enabled`.
- Default values keep current Discord-like list view to avoid disrupting current users.
