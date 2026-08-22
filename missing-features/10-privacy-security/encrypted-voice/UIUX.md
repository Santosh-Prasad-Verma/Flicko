# Encrypted Voice — UI/UX Design

## 1. Design Principles

- Trust depends on visibility: the E2EE badge must be present and unmissable any time the user is in an E2EE room.
- Reuse existing voice-channel UI from `features/voice/`. The E2EE channel is a special-cased variant, not a separate stack.
- Fingerprint verification is opt-in but discoverable — most users never tap it; security-conscious users find it instantly.
- We never simulate cryptography. If the key isn't ready, we show a loading state, not a fake green badge.

## 2. Information Architecture

Where this feature lives:
- Entry points (3): voice-channel list (E2EE channels marked with lock icon); voice-channel screen header (badge); call-info sheet (verify fingerprints).
- Parent navigation: server → voice channels.
- Deep links: same as regular voice channels; the E2EE flag comes from server data.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Voice channel list (E2EE marker) | Show which channels are E2EE | content |
| 2 | E2EE voice channel screen | In-call UI w/ E2EE badge | connecting, encrypted, key-rotating, fallback |
| 3 | Fingerprint verify sheet | Compare codes | content, verified |
| 4 | Setup-required dialog | If user has no identity key | content |
| 5 | Force-upgrade banner | Old client | content |

## 4. Wireframes (ASCII)

### Screen 1 — Voice channel list

```
┌────────────────────────────────────┐
│  General                           │
│  🔊 Lobby            14 in voice   │
│  🔒 Strategy Room     3 in voice   │ ← lock icon
│  🔒 Mods Only        empty         │
└────────────────────────────────────┘
```

### Screen 2 — E2EE voice channel screen (in call)

```
┌────────────────────────────────────┐
│  ← Strategy Room                   │
│  🔒 End-to-end encrypted   [verify]│ ← always visible
├────────────────────────────────────┤
│                                    │
│   ╭───╮  ╭───╮  ╭───╮              │
│   │ A │  │ B │  │ C │              │
│   ╰───╯  ╰───╯  ╰───╯              │
│   you    Alex   Sam                │
│                                    │
│           [ 🎤 ]  [ 🔇 ]  [ ☎ ]    │
└────────────────────────────────────┘
```

If a key rotation is mid-flight: a thin progress bar appears under the badge labeled "rotating keys…" — audio briefly mutes (≤500ms) and resumes.

### Screen 3 — Fingerprint verify sheet

```
┌────────────────────────────────────┐
│  Verify participants               │
├────────────────────────────────────┤
│  Compare these codes with your     │
│  friend out-of-band (in person,    │
│  on a different app, etc.).        │
│                                    │
│  You:    9c4f-3e8a-2d11-7f04       │
│  Alex:   1b22-77c0-9eaa-4d18       │
│  Sam:    f3a1-d8e0-5c12-23bb       │
│                                    │
│            [ Mark verified ]       │
└────────────────────────────────────┘
```

Once a participant is verified, their card shows a small green check next to their name.

## 5. Component Specs

### `E2EEBadge`
- Props: `state: BadgeState (connecting | encrypted | rotating | fallback)`.
- Rendering rule: `encrypted` is the only state with a green tint. `connecting` and `rotating` are amber. `fallback` does not exist in v1; if encryption fails, we drop the call rather than continue unencrypted.
- Tap opens fingerprint sheet (only when `encrypted`).

### `FingerprintVerifySheet`
- Lists participants with their fingerprints; each row tappable to mark verified locally.
- Verified state stored client-side in `secure_storage`; never synced to server (server cannot influence trust).

### `KeyRotationOverlay`
- Half-second amber "rotating keys…" pill atop the participant grid; auto-hides when rotation completes.

## 6. Empty / Error / Loading

- **Connecting:** spinner + "Connecting…" + lock icon greyed.
- **Setup required:** modal "End-to-end encryption needs a one-time setup. Generate your encryption identity now?" with primary button.
- **Old client:** banner "Update Flicko to join encrypted voice channels."
- **Audio decrypt failures spike:** in-call toast "We're having trouble decrypting your friends' audio. Try rejoining."

## 7. Copy

| Surface | Copy |
|---------|------|
| List marker tooltip | End-to-end encrypted |
| Badge label | End-to-end encrypted |
| Verify CTA | verify |
| Sheet title | Verify participants |
| Sheet helper | Compare these codes with your friend out-of-band. |
| Setup modal title | Set up encrypted voice |
| Setup modal body | We'll generate an encryption identity that lives only on your device. |
| Force-upgrade banner | Update Flicko to join encrypted voice channels |

Voice: matter-of-fact, technical when needed but never alarming.

## 8. Motion

- Badge "rotating" pulse: 1 Hz amber for ≤500ms then snaps back to encrypted-green.
- Verify sheet: slide-up 300ms.
- Reduced-motion: replace pulse with static amber, replace slide with crossfade.

## 9. Accessibility

- Badge has Semantics label that reads the current state out loud: "End-to-end encrypted, verified" or "Rotating keys."
- Fingerprint codes use a font with disambiguated O/0 and l/1 (e.g., Inconsolata).
- Tap targets ≥44pt.
- Color is never the only signal: state has icon + text together.
- Screen-reader users get the same information as sighted users for verification.

## 10. Responsive

- Phone: full-screen call view.
- Tablet/web: split — participant grid left, controls right; badge pinned in header on both.
- Foldable: respects display feature.

## 11. Theming

- Light + Dark + AMOLED.
- Encrypted-state green is a slightly desaturated tone to avoid "scammy SSL-padlock-green" connotations.
- Server accent color does not bleed into the badge — privacy state must look identical across servers.

## 12. Privacy-specific UX rules

- Never display "encrypted" before the client has actually loaded a group key and bound it to the Azure ACS `KeyProvider`. The badge is fed by an observable that flips only after that hookup.
- If encryption fails mid-call, drop audio publish immediately, surface the error, and prompt to rejoin. Do not continue with unencrypted audio while showing the badge.
- Recording, transcription, AI-moderation features are visually absent in E2EE rooms — the buttons do not exist, not just disabled, to make the property obvious.
