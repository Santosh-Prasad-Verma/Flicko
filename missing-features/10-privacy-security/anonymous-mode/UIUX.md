# Anonymous Mode — UI/UX Design

## 1. Design Principles

- Match Flicko's existing dark/light theme tokens (see `mobile/lib/core/theme/`).
- Reuse `JoinServerSheet` from `features/server_join/` — extend, do not fork.
- The anon toggle is a *first-class* option in the join flow, not buried in advanced settings.
- Visual language signals "this is a different identity": muted accent color, subtle mask iconography, neutral handle typography.
- No surprises: every screen that shows anon state names it explicitly. We never half-anonymize.

## 2. Information Architecture

Where this feature lives:
- Entry points (3): server-join sheet "Join as Anonymous" toggle; profile screen "Your anonymous identities"; mod panel "Anon Members" tab.
- Parent navigation: server-join flow → join sheet; settings → profile → privacy section.
- Deep links:
  - `flicko://server/<id>/join?anon=1` (preselects anon)
  - `flicko://settings/privacy/anon`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Join sheet (extended) | Choose anon vs real on join | empty, loading, content, error, anon-disallowed |
| 2 | Anon-handle preview | Show generated handle before commit | loading, content, regenerate-loading |
| 3 | Profile › Your anon identities | List per-server anon handles | empty, content |
| 4 | Reveal-identity dialog | Confirm one-way reveal | idle, confirming, error |
| 5 | Mod panel › Anon members tab | Mod tooling | empty, content, ban-action |
| 6 | Server settings › Allow anon joins | Owner toggle + warning | off, on, transitioning |

## 4. Wireframes (ASCII)

### Screen 1 — Join sheet (extended)

```
┌────────────────────────────────────┐
│  Join "Survivor Support"           │
├────────────────────────────────────┤
│                                    │
│  Identity                          │
│  ┌──────────────────────────────┐  │
│  │ ○ Real:  @taylor_2024        │  │
│  │ ● Anonymous (recommended)    │  │
│  └──────────────────────────────┘  │
│                                    │
│  ┌─ Preview ──────────────────┐    │
│  │  🦊 QuietFox4218  ↻        │    │
│  │  This handle is yours      │    │
│  │  for this server only.     │    │
│  └────────────────────────────┘    │
│                                    │
│  Mods can still ban or remove      │
│  you. Your real account stays      │
│  hidden from members and mods.     │
│                                    │
├────────────────────────────────────┤
│                          [ Join ]  │
└────────────────────────────────────┘
```

### Screen 4 — Reveal-identity dialog

```
┌────────────────────────────────────┐
│  Reveal your real identity?        │
├────────────────────────────────────┤
│                                    │
│  Members and mods will see         │
│  @taylor_2024 instead of           │
│  QuietFox4218 from now on.         │
│                                    │
│  This cannot be undone.            │
│                                    │
│  ☐  I understand                   │
│                                    │
│         [ Cancel ]   [ Reveal ]    │
└────────────────────────────────────┘
```

### Screen 5 — Mod panel › Anon members

```
┌────────────────────────────────────┐
│  Anon members  · 14                │
├────────────────────────────────────┤
│  🦊 QuietFox4218         joined 2d │
│     0 warnings · 42 msgs · …       │
│  ────────────────────────────────  │
│  🦉 SilentOwl9930        joined 5h │
│     1 warning · 8 msgs · …         │
└────────────────────────────────────┘
```

The trailing `…` opens a sheet with Ban / Mute / Timeout / Report — none of which expose user_id.

## 5. Component Specs

### `AnonHandlePreview`
- Props: `handle: String`, `avatarUrl: String`, `onRegenerate: VoidCallback`.
- States: `idle`, `regenerating` (skeleton swap), `disabled` (server forbids anon).
- Token usage: `colorScheme.surfaceVariant`, `textTheme.titleMedium`.

### `IdentityPicker`
- Radio group with two options. Default = `anonymous` if server allows it.
- Adds a Material info-row beneath: "Mods can still ban you."

### `RevealConfirmationDialog`
- Two-step: checkbox + button. Button disabled until checkbox checked.

## 6. Empty / Error / Loading

- **Empty (mod panel anon tab):** mask illustration + "No anonymous members yet" + link to "Allow anon joins" setting.
- **Error (handle generation):** inline `Banner` "Couldn't generate handle. Tap to retry."
- **Loading:** skeleton card matching `AnonHandlePreview` shape.
- **Anon-disallowed:** the radio renders the anon option as disabled with tooltip "This server doesn't allow anonymous joins yet."

## 7. Copy

| Surface | Copy |
|---------|------|
| Join-sheet identity title | Identity |
| Anon radio label | Anonymous (recommended) |
| Real-name radio label | Real: {handle} |
| Preview footer | This handle is yours for this server only. |
| Reveal CTA | Reveal real identity |
| Reveal disclaimer | This cannot be undone. |
| Empty mod panel | No anonymous members yet |
| Owner setting | Allow anonymous joins |

Voice: friendly, concise, second-person. No jargon (avoid "HMAC," "hash," "pseudonym").

## 8. Motion

- Identity-picker switch: 200ms crossfade between real/anon preview cards.
- Regenerate handle: avatar spin + handle char-shuffle 400ms; disabled during request.
- Reveal-dialog: scale-in 300ms; checkbox enables button via 150ms color tween.
- Reduced-motion: replace all of the above with instant snaps + opacity fades.

## 9. Accessibility

- Radio group uses semantic `Radio` widgets with `Semantics(label: ...)` — screen reader reads "Anonymous, recommended, selected."
- Avatar SVGs include `Semantics.label` matching the handle ("QuietFox").
- Reveal dialog announces full text via `MediaQuery.accessibleNavigation` live region.
- Color contrast ≥4.5:1 for all anon-mode badges on both light and dark.
- Keyboard: Tab through radios, Space toggles; Enter on the join button.

## 10. Responsive

- Phone: full-screen sheet.
- Tablet/web: centered modal at 480px wide; mod panel is a side-by-side list/detail.
- Foldable: respects display feature; preview pane stays on one side.
- Breakpoints: 360 / 600 / 840 / 1200.

## 11. Theming

- Light + Dark + AMOLED.
- Anon mode uses a desaturated accent (`anonAccent` token: hsl(220, 8%, 60%)) so it reads as "different identity, not your usual self."
- Ignores server accent color — anon UI is intentionally neutral.

## 12. Privacy-specific UX rules

- Never show a member's real `@handle` and their `anon_handle` in the same view, even on the user's own profile. The mapping lives behind a "show real identity" toggle that is hidden by default.
- Avatars in anon mode never use the user's real avatar. They are deterministic procedural shapes seeded from the handle.
- Friend-presence indicators are suppressed in anon-mode servers — no green dot, no "playing X."
- Mentions: typing `@QuietFox` autocompletes the anon handle but never resolves to the real `@handle` even for the user themselves in that server context.
