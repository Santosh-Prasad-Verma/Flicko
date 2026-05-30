# UIUX — Stream Donations

## 1. Surfaces
- Tip composer in the in-app stream player.
- Streamer dashboard donation history and rule editor.
- OBS browser-source alert overlay.
- Email receipt for donor.
- Notification toast on streamer's dashboard.

## 2. Tip Composer
- Triggered by a coin icon button next to the chat composer in the player.
- Modal sheet on mobile, popover on desktop.
- Layout:
  - Currency selector (auto-set to viewer locale).
  - Amount preset chips: $1, $5, $10, $25, $50, $100, custom.
  - Message field, 200-char counter.
  - "Read with TTS" toggle.
  - "Hide my name" toggle (anonymous).
  - Pay button styled by chosen method (Apple Pay / Google Pay / card).
- Stripe Elements card form rendered inline when card method selected.

## 3. Confirmation State
- Loading: "Processing your tip..." with a coin spinning animation.
- Success: "Thanks for supporting <streamer>!" with a confetti burst, link to view alert on stream.
- Error: explicit message ("Card declined", "Network error, retry", "Donations are off for this stream").

## 4. Alert Overlay (OBS)
- Animation tiers:
  - Basic ($1-$4): slide in from left, "<name> tipped $X" text, subtle chime.
  - Standard ($5-$24): coin shower, name + amount + message, brand-colored sound.
  - Hype ($25-$99): bigger animation, particle effects, message displayed sequentially.
  - Legendary ($100+): full-screen takeover for 8s, fireworks, custom video clip if streamer uploaded one.
- TTS plays after 1s of animation; volume normalized to -14 LUFS.
- Alerts queue with min 800 ms gap between, max 3-deep queue; overflow shown sequentially.

## 5. Streamer Rule Editor
- Card-based list of rules sorted by `min_amount` descending.
- Each card: drag handle, amount band, animation preview button, sound preview, TTS voice picker, edit / delete.
- "Add rule" CTA at top creates rule from a template wizard.
- Live preview pane on the right shows the alert at full size.

## 6. Donation History
- Table with columns: timestamp, donor (or "anonymous"), amount, currency, message, status (succeeded/refunded/disputed).
- Filters: date range, amount band, status.
- Row actions: refund, reply with thank-you DM, mark as featured.
- Export CSV button generates a signed download link valid 5 minutes.

## 7. Streamer Notifications
- In-app banner: "New tip from <name> for $X" with thumbnail.
- Email digest daily summarizing donations.
- Mobile push for donations >= $25 (configurable threshold).

## 8. Donor Receipt Email
- Subject: "Thanks for supporting <streamer> on Flicko"
- Body: amount, currency, channel name, donation date, link to channel, refund/dispute support link.
- Plain-text fallback alongside HTML.

## 9. Empty/Loading/Error States
- History empty: "No tips yet. Share your channel to invite supporters."
- Composer offline: "Tipping is offline for this stream. Try again later."
- Composer disabled: "<streamer> hasn't enabled tips yet."
- Webhook delay: composer shows "Confirming with bank..." for up to 30s, then "Almost there, your tip will land shortly".

## 10. Microcopy
- Composer headline: "Tip <streamer>"
- Subhead: "100% goes to the creator after Stripe fees and a small Flicko fee."
- TTS toggle label: "Read my message on stream"
- Anonymous toggle label: "Hide my name on the alert"
- Refund modal: "Refunding will reverse the charge and notify <donor>. This can't be undone."

## 11. Accessibility
- All form fields labeled with explicit `<label>` elements.
- Currency selector keyboard navigable.
- Stripe Elements styled to meet 4.5:1 contrast.
- Alert overlay is decorative only; ARIA hidden. The streamer's dashboard alert log is the accessible surface.
- Reduced motion: alert animations replaced with static reveal honoring `prefers-reduced-motion`.

## 12. Visual Tokens
- Coin icon uses brand gold `#F4B400`.
- Amount chips use `--surface-2` background, `--accent` outline when selected.
- Alert text uses streamer brand color where available, falling back to `--accent`.

## 13. Custom Video Alerts
- Streamer can upload up to 5 MB MP4 (alpha channel supported via WebM/VP9) per legendary rule.
- Preview plays in editor with mute toggle.
- File served from `donation-assets` bucket via signed URL with 24h expiry.

## 14. Settings
- Toggle: enable donations on this channel.
- Minimum tip amount.
- Alert duration cap.
- Profanity filter strictness (off, mild, strict).
- Banned words list with paste-many input.
- TTS voice default and per-rule overrides.
- Daily TTS budget cap.
