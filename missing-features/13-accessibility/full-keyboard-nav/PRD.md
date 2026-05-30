# Full Keyboard Navigation — Product Requirements

> **One-line:** 100% keyboard-accessible Flicko with shortcut catalog, focus rings, and skip-to-content.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** L
> **Priority:** P0
> **Slug:** `full-keyboard-nav`

## 1. Problem

WCAG 2.1 SC 2.1.1 (Keyboard) and 2.1.2 (No Keyboard Trap) require every interactive element to be reachable and operable from a keyboard alone. Discord's web client supports many shortcuts but has gaps: server icons in the rail are not in tab order, voice mute/deafen toggles need awkward chord combos, and modal dialogs occasionally trap focus. Mobile users with external keyboards (e.g. iPad Magic Keyboard, Bluetooth keyboards on tablets, hardware keyboards on Surface Duo) hit dead ends.

Power users — including those who simply prefer keyboard over touch/mouse — also benefit. Slack and Notion have well-known shortcut catalogs and a `?` overlay; Flicko has neither.

## 2. Users & Use Cases

- **Primary persona:** Mehmet, motor-impaired user who navigates exclusively via keyboard + switch.
- **Secondary personas:**
  - Touch-typist power users who hate context switching to a trackpad
  - Tablet users with external keyboards
  - Accessibility auditors verifying SC 2.1.1
- **Top jobs-to-be-done:**
  1. As a keyboard-only user, I want to reach every action in Flicko using Tab/Shift+Tab/arrows, so that I can use the app without a mouse.
  2. As a power user, I want memorable shortcuts and a `?` overlay listing them, so that I can move quickly.
  3. As an auditor, I want to verify there are no focus traps and visible focus rings, so that I can sign off on conformance.

## 3. Goals & Non-Goals

**Goals**
- Every interactive element reachable via standard Tab order; explicit `FocusTraversalGroup` ordering for chat/sidebar/main.
- Visible 2-3px focus ring on all focusable widgets, theme-aware.
- A canonical Shortcuts catalog (40+ entries) opened with `?`.
- Skip-to-content link rendered as the very first focusable widget on each scaffold.
- Tabbed channel switching: `Ctrl+1..9` jumps to indexed channel; `Ctrl+K` opens quick switcher (already exists; we wire keyboard).
- All modals trap focus internally and restore on close.

**Non-Goals (out of scope for v1)**
- Custom user-rebindable shortcuts (planned post-v1).
- Voice command parity (different feature).
- Mobile-only soft-key chording.

## 4. Scope (v1)

- [ ] Root-level `Shortcuts` and `Actions` map with 40+ default bindings.
- [ ] `FocusRing` widget; opt-in for any widget; auto-applied to standard buttons via theme extension.
- [ ] Skip-to-content widget on every scaffold.
- [ ] Shortcut help overlay reachable via `?` and Settings → Accessibility.
- [ ] Channel quick-switcher tabbed activation.
- [ ] Modal focus trap utility.
- [ ] Audit: traverse the top 25 screens by keyboard only and verify reachability.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Keyboard adoption (sessions w/ ≥3 shortcut events) | +200% in 60d | PostHog `shortcut.invoke` |
| Accessibility Scanner keyboard-trap findings | 0 on top 25 screens | nightly CI |
| Time-to-action via keyboard (e.g. send message) | <250 ms median | client trace |
| Help overlay open rate (first-week users) | ≥30% | telemetry |
| Users who close help overlay and use ≥1 shortcut | ≥75% | telemetry |

## 6. Open Questions / Risks

- Web vs. mobile: shortcuts must work on both; mobile only when external keyboard attached (`MediaQuery.of(context).accessibleNavigation` or pointer kind).
- Shortcut conflicts with browser (`Ctrl+W`, `Ctrl+T`) — we never override these on web.
- IME: shortcuts must not trigger while typing CJK/Hindi.
- Locale-specific keyboards (AZERTY, Dvorak): use logical key bindings only.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Decent shortcuts, no `?` overlay, gaps in tab order | Discoverable catalog; fully reachable rails |
| Slack | Strong: `Ctrl+K`, help overlay | Parity + cleaner focus rings |
| Microsoft Teams | Solid keyboard support | Lighter weight, mobile parity |
| Notion | Excellent inline + global shortcuts | We borrow patterns |

## 8. Rollout

- Internal dogfood by motor-impaired users + touch-typist team → 5% beta → GA.
- Kill switch flag: `feature.full_keyboard_nav.enabled` (default ON).
- Companion blog post.
