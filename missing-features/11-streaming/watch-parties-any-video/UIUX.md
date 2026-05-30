# UI/UX: Watch Parties for Any Video

## Design Principles
- The video is the hero. Every chrome element collapses or fades when the user has not interacted in 4 seconds.
- Sync state is always legible. A tiny pill near the timeline says "In Sync", "Catching Up", or "Out of Sync" so members never wonder why the video paused.
- Host actions are unmistakably scoped. Host-only controls glow with the accent color and carry a small crown glyph. Participants see them dimmed with a tooltip explaining the gating.
- The chat sidebar follows Flicko's existing channel chat visual language to remove cognitive load.

## Entry Points
1. **Channel header**: a "Start Watch Party" button appears in voice and stage channel headers when the viewer holds `start_watch_party`.
2. **Slash command**: `/watchparty <url>` in any text channel opens the create sheet pre-filled.
3. **Link unfurling**: pasting a supported provider URL produces a card with a "Watch Together" CTA.
4. **Aura**: asking the AI assistant "watch this together" while a URL is in clipboard opens the create sheet.

## Create Sheet
A bottom-sheet modal on mobile, centered dialog on web. Fields:
- URL input with live validation; success state shows a 16:9 thumbnail and detected provider badge.
- Party name (auto-suggested from video title).
- Linked voice channel dropdown filtered to channels the host can join.
- Schedule toggle. When on, a date-time picker appears; the create button label flips to "Schedule".
- Privacy switch: server-only (default) or invite-only with a copyable link.

The primary CTA is disabled until resolution succeeds. If the provider returns `embeddable: false`, the sheet shows a non-blocking warning explaining the source cannot be embedded and offers to copy the link instead.

## Party Screen Layout

### Mobile (Portrait)
- Top: 16:9 video player pinned to the safe area.
- Below the player: a sticky control bar (play/pause, scrub, position/duration, fullscreen, sync pill).
- Tabs: `Chat` (default) and `Reactions`.
- Chat is a full-height list with the composer at the bottom; reactions are a dense grid of recent emoji bursts with timestamps.
- A floating "Sync" FAB appears only when local drift exceeds 1 second.

### Mobile (Landscape) and Tablet
- Player fills the left two-thirds; chat occupies the right third with a slim 280 dp width.
- Tapping the player toggles full-bleed mode that hides chat for 6 seconds.

### Web
- 16:9 player center stage, max width 1200 px.
- Right rail (340 px) hosts chat and a participant list collapsed by default.
- Top bar shows party title, host avatar with a crown, participant count, and a "Leave" button.

## Player Controls
- Scrub bar shows a heat map of reactions; tapping a peak seeks to that moment.
- Volume slider is local-only; volume never syncs.
- Subtitle picker mirrors provider-native captions where available.
- Quality toggle for MP4/HLS sources only.
- Host-only: pause, resume, seek, change source, end party. Each host action triggers a 250 ms accent flash on the affected control to acknowledge the command landed.

## Sync Pill States
- **In Sync** (green): drift under 200 ms.
- **Catching Up** (amber): drift 200 to 600 ms; subtitle "we are speeding up briefly".
- **Out of Sync** (red): drift over 600 ms; tap to hard-seek.
- **Reconnecting** (gray, pulsing): data channel down, falling back to gateway.

## Chat Sidebar
- Inherits typography, mention rules, and reaction emojis from the parent channel chat.
- A pinned system message at the top of the chat shows the active source title and the host name; updates on host change with a "Crown handed to @user" pill.
- Slash commands respected: `/timestamp` posts the current playback position formatted as `HH:MM:SS`.

## Notifications and Presence
- Server members with `join_watch_party` receive a non-blocking banner: "Watch party started in #movie-night: Inception". Tapping joins.
- Scheduled parties appear in the server's "Upcoming" list and emit reminder pushes 10 minutes before.
- The voice channel badge shows a small film-reel icon while a party is live in that room.

## Empty and Error States
- **Resolver fail**: inline red helper text "We could not load that link. Try a YouTube, Twitch, Vimeo, or direct MP4 URL."
- **Live source ended**: a full-width banner across the player with two actions: "Switch to VOD" (when available) or "End party".
- **Network blip**: a translucent toast at the player bottom: "Reconnecting to sync. Playback will resume shortly."
- **No participants yet**: chat shows an illustrated empty state with a one-tap "Invite server" button.

## Accessibility
- Captions enabled by default when the provider supports them.
- All controls reachable via keyboard with a visible focus ring matching Flicko's `--focus-ring` token.
- Sync pill state changes announced via `aria-live="polite"`.
- Reduced motion preference disables the playback-rate nudge animation; clients hard-seek instead.
- Minimum touch target 44 dp; controls auto-grow on TV layouts to 64 dp.

## Motion and Sound
- Player chrome fades over 200 ms with the standard `motion-emphasized` curve.
- A short rising glissando plays when a party starts and a softer descending one when it ends. Both respect the global "Play sounds" preference.
- Reactions float upward from the bottom-right of the player, staggered 80 ms apart, capped at 6 simultaneous to avoid clutter.

## Edge Cases the UI Must Handle
- Host changes while a participant is mid-seek: the manual seek wins for the participant locally for 3 seconds, then snaps to the new host's position.
- Source change with the chat sidebar scrolled up: a "Source changed" pill appears at the top of the chat, tap to jump to the system message.
- Party paused by a moderator: every control disables, a banner explains why and who, with a "Contact mods" link.
