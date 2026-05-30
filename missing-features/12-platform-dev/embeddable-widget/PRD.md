# PRD: Embeddable Widget

## Problem
Flicko communities live behind login. Newsletter readers, blog visitors, course students, and game players cannot see what is happening inside a server without signing up first. Communities lose discovery momentum because there is no light-touch way to drop a Flicko presence on an external website. Competitors like Discord offer iframe widgets and Slack offers shareable channels; Flicko has none.

## Goal
Ship a tiny vanilla-JS embed snippet that any website can paste into their HTML to show a live Flicko channel feed, member presence, and a "Join the conversation" CTA. The widget renders inside an iframe pointed at `chat.flicko.app/embed`. Server admins generate embed keys, allowlist origins, and pick which channels are public.

## Non-Goals
- Full Flicko desktop app inside a webpage (too heavy, security risk).
- Voice or video embeds in v1.
- Anonymous posting from the widget in v1 (read-only plus magic-link join CTA).
- Custom widget themes per page in v1 (light, dark, auto only).

## Users
- Server admin: configures which channels are public, generates embed keys.
- Site owner: pastes the snippet onto their marketing site, blog, or game.
- Visitor: views the live channel feed and clicks join CTA.

## User Stories
- A creator pastes the snippet on their landing page; visitors see the latest 50 messages from #general updating in real time.
- A game studio embeds the widget on a game wiki; visitors see who is online and what build patches dropped today.
- A course operator embeds the widget on the lesson page tied to the course's #cohort-2026 channel; students get class chat without leaving the LMS.
- An admin rotates an embed key after a leak; previous embeds stop working immediately.

## Non-Functional Requirements
- Bundle size for the loader script under 4 KB gzipped. The iframe app loads on demand.
- Time to first message rendered inside the iframe under 1.2 seconds on cable.
- Zero impact on host page performance: no global CSS, no DOM mutations outside the inserted iframe, no synchronous network calls.
- Strict CORS allowlist: messages only accepted from origins listed against the embed key.

## Success Metrics
- 5,000 active embeds in the first 90 days.
- Average click-through to "Join Server" 4 percent of widget views.
- Less than 0.5 percent of pageviews see widget render errors.
- Zero security incidents linked to embed (XSS, origin spoofing).

## Pricing Tier
Free servers: 1 embed key, "Powered by Flicko" badge required, view limit 100k per month. Pro: 10 keys, branding optional, 1M views per month. Enterprise: unlimited.

## Risks
- XSS from message content rendered in iframe. Mitigated by rendering messages with a strict sanitizer that allows only paragraphs, mentions, links (rel=noopener), and emoji. No HTML from user content.
- Origin spoofing to bypass allowlist. Mitigated by checking the iframe `referrer` plus sending a server-issued nonce per embed load that validates origin server-side.
- Real-time fan-out at scale. Mitigated by Centrifugo presence/subscribe with read-only permissions, plus per-key view rate limit.

## Launch Plan
- Week 1 to 2: backend embed key endpoints and migration 245.
- Week 3 to 4: widget iframe app at `chat.flicko.app/embed`.
- Week 5: tiny vanilla-JS loader at `widget-embed/`.
- Week 6: admin UI at `Settings → Developers → Embeds`.
- Week 7: closed beta with 50 sites.
- Week 8 to 9: GA, copy-paste templates, Wix/Webflow guides.
