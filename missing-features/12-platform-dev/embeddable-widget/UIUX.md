# UIUX: Embeddable Widget

## Two Surfaces
1. The widget itself, rendered inside the embed iframe on third-party sites.
2. The admin embed-key manager inside Flicko, at `Settings → Developers → Embeds`.

## Widget (Iframe) Layout
Single column, fits any container 320 to 720px wide. Default height 480px, configurable via `data-height`.

### Anatomy (top to bottom)
- **Header (52px)**: server avatar (32px circle), server name bold, channel name with `#` prefix below in 12px muted. Right side: presence dot + count "12 online".
- **Message list**: virtualized, newest at bottom. Each message has 28px avatar, name in accent, time in 11px muted, body 14/20. Mentions are highlighted; URLs render as inline cards with title + favicon (cards lazy-loaded).
- **Composer area**: replaced by an inviting CTA strip "Join the conversation on Flicko". Primary button right-aligned: "Join Server".
- **Footer (28px)**: optional "Powered by Flicko" badge with logo. Free tier: required and not removable. Pro tier: hidden by default unless `data-flicko-badge="true"`.

### Themes
- `light`: background `#FFFFFF`, text `#16181D`, accent `#3D89F5`.
- `dark`: background `#0E0F11`, text `#E5E7EB`, accent `#3D89F5`.
- `auto`: respects `prefers-color-scheme` of the host page.
- Border radius 12px on the iframe wrapper. Shadow `0 8px 24px rgba(0,0,0,0.08)` light, `0 8px 24px rgba(0,0,0,0.5)` dark.
- Inter font with system-ui fallback, no remote font loaded inside the iframe.

### Loading State
- Skeleton: header gray bar, three skeleton messages with shimmer.
- Skeletons collapse out as data resolves; no layout shift.

### Error / Empty
- "This Flicko widget is unavailable" with neutral cloud icon. No mention of which key was bad (avoids enumeration).
- No messages yet: friendly empty state with a small wave illustration and "Be the first to chat".

### Interaction
- Click "Join Server": opens `https://flicko.app/invite/{server_slug}` in a new tab. Posts `flicko:join-clicked` to the parent for analytics.
- Click an avatar or name: opens member profile in a new tab.
- Scroll to top: loads older messages via infinite scroll, max 250 messages.

## Admin Manager UI
Path: `Server → Settings → Developers → Embeds`.

### Layout
- Page header "Embeds" with "New embed key" button right.
- Table with columns: name, key prefix, channels, allowed origins (chip list, +N more), views this month, status, actions.
- Right rail with usage gauge (views vs cap), and a "Best practices" callout.

### Create / Edit Drawer
- Field: name (free text).
- Field: allowed channels (multi-select, only public-eligible channels listed).
- Field: allowed origins (chip input, paste a URL, validates schema). Wildcard hint shown.
- Field: theme (light, dark, auto).
- Field: badge (toggle, locked on for free tier).
- Field: dev mode (toggle, allows `localhost`).
- Save persists the row and shows a generated snippet card with copy button.

### Snippet Card
Shows the exact `<script>` plus `<div data-flicko-embed>` markup. "Copy" button. "Preview" button opens a sandboxed preview tab.

### Rotate Confirmation
Modal: "Rotate this embed key? Existing embeds will stop working until updated. This cannot be undone." Requires typing the key name.

## Admin Visual Tokens
- Status pills: Active green, Disabled gray, Revoked red.
- Origin chips: 12px pill, host name only, max 3 visible plus a `+N` overflow chip with hover tooltip.
- Code block uses the existing `<CodeBlock>` component, copy button on hover.

## Microcopy
- Snippet helper: "Paste this just before the closing `</body>` tag on your site."
- Origin hint: "Only websites you list here can load this embed. Wildcards like `https://*.example.com` are allowed."
- Free tier nudge: "Upgrade to Pro to remove the Powered by Flicko badge and unlock 1M monthly views."

## Accessibility
- Iframe widget has `aria-label="Flicko community feed"` on its root.
- Keyboard focus moves through messages with arrow keys when the list is focused.
- All interactive elements meet 44px tap target on mobile.
- Color contrast tested for both themes against the live message backgrounds.

## Localization
- Widget UI strings localized via `i18n.json` baked into the bundle. v1 ships with English; Portuguese and Hindi follow within 30 days using existing translation infra.

## Mobile Iframe
- On screens under 480px wide, the widget hides the composer CTA strip and shows a sticky "Join" button bottom-right.
- Avatar size shrinks to 24px to keep density.
