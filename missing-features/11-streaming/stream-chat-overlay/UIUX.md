# UIUX — Stream Chat Overlay

## 1. Surfaces
- Streamer Dashboard chat panel (web + mobile).
- Viewer chat panel inside the live stream player (web + mobile).
- OBS browser-source overlay (presentational).
- Mod toolbar that floats on hover for users with `mod` role.

## 2. Visual Language
- Tokens align with Flicko design system: `--surface-1`, `--surface-2`, `--accent`, `--text-1`, `--text-2`.
- Bubble radius `12px`, padding `8px 12px`, max-width 480 px on overlay.
- Username color hashed from user_id using HSL with luminance pinned at 60% to maintain contrast against any background.
- Emotes rendered at `1em` line-height inline; large emote-only messages bump to `2.4em`.

## 3. Streamer Dashboard Panel
- Three-column layout: emote/mode toolbar (left, 56 px), message list (center, fluid), info pane (right, 280 px) showing presence count, slowmode state, mod queue.
- Sticky composer at the bottom with `/command` autocomplete dropdown.
- Mode chips above the list show active modes: `Slow 30s`, `Emote-only`, `Follower-only 10m`. Tap to toggle.
- Mod queue tab lists messages flagged by AutoMod awaiting allow/deny.

## 4. Viewer Chat Panel
- Side-docked on tablet/desktop, bottom-sheet on mobile (drag handle to expand).
- Empty state: "Be the first to say hi to <streamer>" with a wave emote shortcut.
- Slowmode countdown overlays the send button as a circular progress ring.
- Banned state: composer replaced by "You can't chat in this stream" with mod contact link.
- Follower-only state: composer replaced by "Follow <streamer> to chat" CTA, follow button inline.

## 5. Composer
- Plain-text input with emote autocomplete triggered by `:`.
- Emote picker icon opens a 4x4 grid sheet with channel-owned, recents, and global tabs.
- `@mention` autocomplete pulls from active presence.
- Soft-limit 500 chars with a counter at 450; hard reject at 500.

## 6. Moderator Tools
- Hover any bubble shows a chevron menu: Delete, Timeout (1m/10m/1h), Ban, Pin.
- Pinned message renders at the top of the list with a pin icon, max one pinned at a time.
- Mod action toast: "Timed out @user for 10m" with Undo for 5 seconds.

## 7. OBS Overlay
- Transparent background, no chrome, no scrollbars.
- Default theme: dark frosted bubbles with 4 px accent stripe matching channel brand color.
- Neon theme: glowing edges, monospace font, animated emote shimmer.
- Minimal theme: text-only with subtle drop shadow, no avatars.
- Animation: bubbles slide up 8 px with fade-in over 220 ms, fade out at fade timeout.
- Top-aligned vs bottom-aligned via `?align=top|bottom` query param.

## 8. Empty, Loading, Error States
- Loading: skeleton bubbles in shimmer.
- Connection lost: amber banner "Reconnecting..." with retry counter.
- Centrifugo refused token: red banner "Chat unavailable, contact support".
- Empty stream: "Chat starts when <streamer> goes live" with a bell icon to set a notification.

## 9. Accessibility
- Dashboard and viewer panels meet WCAG 2.1 AA.
- Keyboard: `J/K` to navigate messages, `D` to delete (mods), `T` to timeout, `B` to ban.
- Screen reader: announces username + message via `aria-live=polite`, but throttled to 1/sec to avoid flooding.
- Motion: respects `prefers-reduced-motion`, replacing slide-in with instant render.
- Contrast: usernames must keep 4.5:1 against bubble background; the hash function rotates hue, fixed luminance enforces contrast.

## 10. Microcopy
- "Slowmode is on. Try again in 12s."
- "Emote-only mode is on. Send an emote to chat."
- "You're timed out for 10 more minutes. Hang tight."
- "Banned by @mod_name. Reason: spam."
- "Connect to chat" (button label when offline).
- "Pop out chat" (overlay launch button on dashboard).

## 11. Settings
- Theme selector with previews.
- Fade timeout slider 5 s to 5 min.
- Toggle: show timestamps, show avatars, show badges.
- Custom CSS textarea (Pro tier) with live preview and lint warnings.
- Copy overlay URL button with regenerate-token action.

## 12. Responsive Behavior
- Mobile: bottom sheet docks to 30% height, drag to 80%.
- Tablet: side dock 360 px wide, can collapse to 56 px badge dock.
- Desktop: full side panel, optional pop-out window.
- Overlay: width follows viewport, max 480 px bubbles, scales font with `clamp(14px, 1.6vw, 20px)`.
