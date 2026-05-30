# Screen Reader Full Support — Product Requirements

> **One-line:** TalkBack/VoiceOver/NVDA-grade screen-reader coverage for every Flicko surface.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** XL
> **Priority:** P0
> **Slug:** `screen-reader-full`

## 1. Problem

Discord's screen reader story is famously incomplete. Forum threads (`reddit.com/r/discordapp` "TalkBack unusable", Discord support feedback `#accessibility`, the long-running `discord-jumper` userscript) document recurring pain: unlabeled icon buttons, server lists read as "button button button", message threads read in reverse, message reactions announced as raw emoji codepoints, voice-channel join state unspoken, and modals trapping focus without an exit announcement. WCAG 2.1 SC 4.1.2 (Name, Role, Value) and SC 1.3.1 (Info and Relationships) are routinely violated.

Flicko inherits the same risk because most of our widgets render as `Container` + `GestureDetector` with no `Semantics` wrapper. Screen reader users (~2.2% of mobile users globally per WebAIM 2025) cannot reliably:

- Identify which server/channel they are in
- Hear new chat messages as they arrive
- Discover icon-only actions (mention, reply, react)
- Cross modals, dialogs, and bottom sheets without losing focus
- Differentiate "you" vs "another member" voice-state changes

Building first-class screen reader support is the cornerstone of WCAG 2.1 AA conformance and a clear differentiator vs. Discord.

## 2. Users & Use Cases

- **Primary persona:** Asha, blind university student, uses TalkBack daily on Pixel 8. She joins study-group servers and depends on accurate live announcements.
- **Secondary personas:**
  - Low-vision power users who pair magnification with VoiceOver
  - Motor-impaired users who use switch-control + screen reader
  - QA testers and accessibility auditors at partner organizations
- **Top jobs-to-be-done:**
  1. As a blind user, I want every interactive element to announce its name, role and state, so that I can navigate Flicko without sighted help.
  2. As a TalkBack user, I want incoming chat messages to be read aloud automatically when I am viewing a channel, so that I can follow conversations in real time.
  3. As an auditor, I want to traverse Flicko by landmarks (banner, navigation, main, complementary, contentinfo), so that I can verify SC 1.3.1 conformance.

## 3. Goals & Non-Goals

**Goals**
- 100% of P0 user surfaces (chat, voice, server list, channel list, member list, search, settings, profile, onboarding, calls) ship with `Semantics` annotations validated by automated `flutter_accessibility_test` golden checks.
- Live-region announcements for inbound chat messages, typing indicators, voice-state changes, and toast/snackbar copy.
- Landmark roles (header, navigation, main, complementary) on every scaffold via `Semantics(container: true, role: SemanticsRole.banner)` and equivalents.
- Pass axe-flutter and Accessibility Scanner with zero P0 issues on the top 25 screens.

**Non-Goals (out of scope for v1)**
- Custom screen reader (we rely on the OS reader)
- Braille display tuning (covered by OS layer)
- Full WCAG 2.2 AAA — v1 is AA
- Sign-language video interpretation

## 4. Scope (v1)

- [ ] Semantics audit + retrofit on the 25 highest-traffic widgets (see TRD section 2)
- [ ] `LiveRegion` wrapper around chat message list (assertive vs. polite by setting)
- [ ] `Semantics(role: ...)` landmark structure on `Scaffold` ancestors
- [ ] Focus order tooling: a debug overlay that prints `Focus.of(context).traversalEdges`
- [ ] User-facing setting: "Verbose announcements" toggle (ON by default for users who set system reader on)
- [ ] Accessibility-focused widget catalog page (dogfood, dev-only)
- [ ] Per-locale string review for screen reader phrasing (no abbreviations, no emoji shortcodes)
- [ ] Telemetry event `accessibility.semantics_missing` fired in debug to flag regressions

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Screen reader DAU using Flicko ≥3 days/week | +400% vs. pre-launch | PostHog `accessibility.session.start` segmented by `assistive_tech=screen_reader` |
| Accessibility Scanner P0 issues | 0 on top 25 screens | nightly CI on emulator |
| Manual TalkBack/VoiceOver test pass rate | 100% on regression suite | quarterly audit |
| Time to first announced message in channel | <500 ms | client trace `chat.first_announce_ms` |
| Verbose mode adoption | ≥60% of users with system reader on | preference setting metric |
| WCAG 2.1 AA score (Deque axe) | ≥98 | weekly audit run |

## 6. Open Questions / Risks

- TalkBack on Android 14 sometimes ignores `LiveRegion` when widget rebuilds — mitigation: stable widget keys + `aria-atomic` equivalent (`Semantics(container: true)`).
- VoiceOver rotor support on Flutter is limited; we document this gap.
- iOS reads emoji descriptions verbosely; we may need a "compact emoji" filter.
- Performance: extra `Semantics` widgets cost ~3-5% extra build time; acceptable.
- Translation cost: rewrites in 32 locales (deferred to 14-localization).

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Inconsistent labels, no live regions, focus traps in modals | Comprehensive `Semantics` retrofit, live region for messages |
| Slack | Decent labels, partial live region | Cleaner landmark structure, free tier |
| Microsoft Teams | Strong AT support but heavy UI | Lighter mobile UX with same AT depth |
| Element/Matrix | Community-driven, partial coverage | Backed-by-vendor parity + tests |

## 8. Rollout

- Internal dogfood with 5 blind testers (recruit via Be My Eyes/Aira community) → 1% beta with `assistive_tech=screen_reader` segment → 10% → GA.
- Kill switch flag: `feature.screen_reader_full.enabled` (default ON; flag exists only to disable verbose mode if regressions surface).
- Companion blog post + a11y changelog at GA.
