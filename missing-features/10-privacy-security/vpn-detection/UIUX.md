# VPN Detection — UI/UX Design

## 1. Design Principles

- The warning is informational, not accusatory. We say "looks like" not "is."
- The user's path forward is always clear: Continue, Switch off VPN, Get help.
- Detection happens server-side; the UI surfaces a result, never asks the user to "verify" their network.
- Privacy is the headline: explain what we store and why.

## 2. Information Architecture

Where this feature lives:
- Entry points: post-login banner; post-signup banner; settings → security → recent sessions.
- Parent navigation: auth flow.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Post-login banner | Inform user of VPN signal | content |
| 2 | Explainer sheet | What we store and why | content |
| 3 | Recent sessions list | History with VPN flags | empty, content |

## 4. Wireframes (ASCII)

### Post-login banner
```
┌────────────────────────────────────┐
│  ⓘ Your connection looks like      │
│    it's via a VPN.                 │
│                                    │
│   [ Why am I seeing this? ]        │
│   [ Continue ]                     │
└────────────────────────────────────┘
```

### Explainer sheet
```
┌────────────────────────────────────┐
│  About this notice                 │
├────────────────────────────────────┤
│  Some VPN, proxy and hosting       │
│  networks look distinctive in      │
│  network data. We surface this so  │
│  you can confirm it's you.         │
│                                    │
│  We store:                         │
│  • a hashed version of your IP     │
│  • the VPN signal (yes/no)         │
│  • the country and network name    │
│                                    │
│  We don't store your raw IP.       │
│                                    │
│  Continuing is fine; if it wasn't  │
│  you, change your password.        │
└────────────────────────────────────┘
```

### Recent sessions list
```
┌────────────────────────────────────┐
│  Recent sessions                   │
├────────────────────────────────────┤
│  Today  14:00   FR · OVH (VPN ⓘ)   │
│  Today  09:12   IN · Jio           │
│  Yest   22:08   IN · Jio           │
└────────────────────────────────────┘
```

## 5. Component Specs

### `VpnWarningBanner`
- Props: `country`, `asnOrg`, `onContinue`, `onExplain`.
- States: collapsed (small banner), expanded (sheet).

### `VpnExplainerSheet`
- Static content, modal sheet.

### `RecentSessionsList`
- Reads `auth_security_events` for the current user.
- Each row: time, country, ASN org, badge if VPN/proxy/Tor.

## 6. Empty / Error / Loading

- **Loading:** skeleton banner — but in practice the result is in the auth response so no loading shown.
- **Error (provider unavailable):** no banner; we silently skip rather than show a misleading message.

## 7. Copy

| Surface | Copy |
|---------|------|
| Banner title | Your connection looks like it's via a VPN. |
| Banner CTA | Continue |
| Banner secondary | Why am I seeing this? |
| Explainer body | (see wireframe) |
| Sessions row badge | VPN |

Voice: matter-of-fact, transparent. Avoid security-theater language.

## 8. Motion

- Banner slide-in 200ms.
- Explainer sheet slide-up 300ms.
- Reduced-motion: crossfade.

## 9. Accessibility

- Banner has `Semantics(label: "Notice: your connection looks like a VPN")`.
- Explainer sheet uses standard scrollable region.
- Tap targets ≥44pt.
- Color is supportive only — icon + text carry meaning.

## 10. Responsive

- Phone: full-width banner under app bar.
- Tablet/web: 480px banner.

## 11. Theming

- Neutral info-tone (blue-grey) — never red. Red would imply danger; this is informational.
