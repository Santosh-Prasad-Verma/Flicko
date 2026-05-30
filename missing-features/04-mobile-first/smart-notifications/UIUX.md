# Smart Notifications - UIUX

## 1. Design Principles

- **Trust over magic**: every classification choice is explainable and reversible.
- **Default-good**: minimal setup; the system makes confident first guesses.
- **Light-weight feedback**: a single thumb fixes future similar messages.
- **Calm**: reduce buzz frequency; let the user feel the silence as a feature, not a bug.

## 2. Screen Inventory

1. Notification Settings hub
2. Quiet Hours / Digest configuration
3. Per-channel override sheet
4. "Why this?" explainer screen
5. In-app inbox with tier ribbons

## 3. Wireframes

### 3.1 Notification Settings Hub

```
┌─────────────────────────────────────────────┐
│ ‹  Notifications                       ⚙   │
├─────────────────────────────────────────────┤
│  Smart notifications              [ ON  ]  │
│  Use AI on this device to silence noise     │
│  and only buzz for what matters.            │
│                                             │
│  ── PRIORITIES ─────────────────────────────│
│  Urgent          buzz + bypass DND   [edit] │
│  Relevant        buzz                [edit] │
│  Social          silent inbox        [edit] │
│  Noise           hourly digest       [edit] │
│                                             │
│  ── QUIET HOURS ────────────────────────────│
│  10:00 PM → 7:00 AM  Urgent only     [edit] │
│                                             │
│  ── PER-CHANNEL OVERRIDES ──────────────────│
│  #oncall        Always urgent        [edit] │
│  #random        Never above noise    [edit] │
│  + Add override                             │
│                                             │
│  ── DIAGNOSTICS ────────────────────────────│
│  Classifier: Gemini Nano (on-device)        │
│  Last 24h: 312 classified, 22 buzzed        │
└─────────────────────────────────────────────┘
```

Copy:
- Toggle subtitle: "Use AI on this device to silence noise and only buzz for what matters."
- Tier descriptions:
  - Urgent: "Direct calls, on-call alerts, time-sensitive asks."
  - Relevant: "Threads you're in, mentions, questions for you."
  - Social: "Casual chatter where you usually engage."
  - Noise: "Background server activity."

### 3.2 Quiet Hours Sheet

```
┌─────────────────────────────────────────────┐
│ ‹  Quiet Hours                              │
├─────────────────────────────────────────────┤
│  Quiet hours                       [ ON  ]  │
│                                             │
│  Start  ┌───────┐    End  ┌───────┐         │
│         │ 10:00 │         │ 07:00 │         │
│         │  PM   │         │  AM   │         │
│         └───────┘         └───────┘         │
│                                             │
│  During quiet hours, deliver:               │
│   ◉ Urgent only                             │
│   ◯ Urgent + Relevant                       │
│   ◯ Nothing (silent inbox + digest)         │
│                                             │
│  Allow Urgent to bypass DND      [ ON  ]    │
│  ⓘ Calls + on-call channels can ring        │
└─────────────────────────────────────────────┘
```

### 3.3 "Why this?" Explainer

```
┌─────────────────────────────────────────────┐
│ ‹  Why this notification                    │
├─────────────────────────────────────────────┤
│  Riya in #general                           │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │ "are we still on for 4pm?"              ││
│  └─────────────────────────────────────────┘│
│                                             │
│  Tier: Relevant                             │
│  Reason: question directed to active        │
│  participant, no on-call signal             │
│                                             │
│  Classified by: Gemini Nano (on-device)     │
│  Latency: 92 ms                             │
│                                             │
│  ── DOES THIS LOOK RIGHT? ──────────────────│
│   [ 👍 Yes ]   [ 👎 Lower priority ]        │
│                [ ⬆  Mark urgent  ]          │
│                                             │
│  Override #general's tier   [ Configure ]   │
└─────────────────────────────────────────────┘
```

### 3.4 In-App Inbox With Tier Ribbons

```
┌─────────────────────────────────────────────┐
│  Inbox                              [filter]│
├─────────────────────────────────────────────┤
│ █ URGENT                                    │
│ │  #oncall    PagerDuty alert 12:04 AM      │
│ │  Memory > 90% on prod-7                   │
│                                             │
│ █ RELEVANT                                  │
│ │  Riya       are we still on for 4pm? 10:31│
│ │  #general   Asha mentioned you      9:51  │
│                                             │
│ █ SOCIAL  (12)                              │
│ │  3 channels tap to expand                 │
│                                             │
│ █ NOISE  (38) - next digest 1:00 PM         │
└─────────────────────────────────────────────┘
```

Tier ribbon colors:
- Urgent: `#FF5757` (alert red)
- Relevant: `#7B5BFF` (Flicko purple)
- Social: `#5BC0FF` (calm blue)
- Noise: `#7A7A85` (neutral gray)

## 4. Motion

- New notification slides in from the top with 250 ms cubic ease.
- Tier ribbon fills with a 200 ms color sweep.
- Feedback thumbs animate `1 -> 1.15 -> 1` over 180 ms with subtle haptic.
- Digest delivery: a single notification animates in with a pluralized title ("12 messages while you were away").

## 5. Copy

- Daily digest title: "While you were heads-down: 12 messages."
- Empty inbox: "All caught up. We'll only buzz for what matters."
- First-launch onboarding: "Flicko learns what's noise on this device. Nothing is sent to our servers."
- Feedback success: "Got it. We'll calibrate."
- DND-bypass consent: "Allow urgent messages to ring even with DND on?"

## 6. Accessibility

- Tier color pairs include a glyph (`!`, `*`, `~`, `.`) so colorblind users can distinguish without color.
- VoiceOver / TalkBack reads "Tier urgent" / "Tier relevant" before the message.
- Quiet-hour pickers are spinnable via large stepper buttons; tap-and-type remains available.
- Settings is fully keyboard-traversable (relevant for paired keyboards on tablets).
- All animations respect `Reduce Motion`.

## 7. Theming

Inherits global theme. Tier ribbons keep their hue across light/dark; we adjust luminance to maintain 4.5:1 contrast against background.

## 8. Localization

ARB strings under `mobile/lib/features/smart_notifications/l10n/`. v1 ships en, hi, es, fr, ja, pt-BR. Tier labels are translatable; ribbon glyphs are language-neutral.

## 9. Notification Channels (Android)

- `flicko_urgent` - high importance, sound on, bypass DND if user opted in.
- `flicko_relevant` - default importance, vibrate.
- `flicko_social` - low importance, no sound.
- `flicko_digest` - low importance, no sound, group summary capable.

## 10. iOS Notification Categories

- `URGENT` - critical alert (requires entitlement; we request it once during onboarding for users who pick "On-call user").
- `RELEVANT` - active.
- `SOCIAL` - passive, no banner during focus.
- `DIGEST` - time-sensitive bundled.

## 11. Onboarding (4 cards)

```
┌──────────────────────────┐
│ 1                        │
│ Tired of buzzing for     │
│ everything?              │
│                          │
│ Flicko learns what's     │
│ noise. Quietly.          │
│                          │
│       [continue]         │
└──────────────────────────┘
```

```
┌──────────────────────────┐
│ 2                        │
│ It runs on this device.  │
│                          │
│ Your messages never      │
│ leave the phone for      │
│ ranking.                 │
└──────────────────────────┘
```

```
┌──────────────────────────┐
│ 3                        │
│ Pick a quiet window.     │
│                          │
│ ┌────────┐  ┌────────┐   │
│ │10:00 PM│  │7:00 AM │   │
│ └────────┘  └────────┘   │
└──────────────────────────┘
```

```
┌──────────────────────────┐
│ 4                        │
│ Want urgent through DND? │
│                          │
│ [Allow]   [Maybe later]  │
└──────────────────────────┘
```

## 12. Edge UI Cases

- Model still downloading: settings shows a progress bar and "Heuristic mode active".
- Capability lost (e.g., AICore disabled): banner "Smart classification paused" with link to status page.
- Heavy correction (>10 thumbs in a week): toast "Calibrated to your taste".
