# UIUX: App & Theme Store

## Principles
- Discovery, not maze. Surface a curated row first, search behind a tap.
- Truthful pricing. No hidden currency conversion shocks; show local currency from the start.
- Honest reviews. Star average shown only after 5 reviews; before that we show review count plus "early access".

## Screen 1: Store Home
```
+----------------------------------------------------+
| Store              [Q search]              [Cart]  |
+----------------------------------------------------+
| Featured                                            |
| +------+  +------+  +------+                        |
| |Theme |  |Plug  |  |Stkr  |                        |
| |Aurora|  |AutoMd|  |Cats  |                        |
| | Free |  | $4.99|  | Free |                        |
| +------+  +------+  +------+                        |
|                                                     |
| Categories                                          |
| [Themes] [Plugins] [Stickers] [Sounds]              |
|                                                     |
| Trending this week                                  |
|  1. Welcomer Pro     4.7 stars (1.2k)   Free        |
|  2. Neon Theme        4.4 stars (804)   $1.99       |
|  3. ModerationKit     4.6 stars (211)   $9.99/mo    |
|                                                     |
+----------------------------------------------------+
```
Copy: featured row max 6 items, hand-curated weekly.

## Screen 2: Listing Detail
```
+----------------------------------------------------+
| < Store        [share]                              |
|                                                     |
| [hero image / theme preview carousel]               |
|                                                     |
| Welcomer Pro                  4.7 stars (1.2k)      |
| by Acme Co.   Verified                              |
|                                                     |
| Free           [Install]                            |
|                                                     |
| About                                               |
|   Greets new members and assigns starter role.      |
|   Read more                                         |
|                                                     |
| Capabilities                                        |
|  - send messages in a channel you choose            |
|  - read member.joined event                         |
|                                                     |
| Reviews                                             |
|  Sarah K. - 5 stars                                 |
|   Setup took 30 seconds. Works.                     |
|  Mark T. - 4 stars                                  |
|   Wish it had multi-language greetings.             |
|                                                     |
| [See all reviews]                                   |
+----------------------------------------------------+
```
- Install button changes to "Buy $4.99" or "Subscribe $1.99/mo" based on listing type.
- Capabilities bullet list reuses Plugin System UIUX strings for consistency.

## Screen 3: Reviewer Console (Web)
```
+--------------------------------------------------------+
| Review Queue (12)        SLA: 6h to 18h target          |
+--------------------------------------------------------+
| [ ] Welcomer Pro v2.0         submitted 2h ago   high   |
| [ ] Neon Theme v1.1           submitted 4h ago   normal |
| [ ] ModerationKit v3.0 (cap+) submitted 1h ago   high   |
+--------------------------------------------------------+
| Selected: ModerationKit v3.0                            |
|                                                          |
| Diff vs v2.4                                             |
|  + scope: voice:transcript                               |
|  + http_allow: api.modkit.io                             |
|                                                          |
| Capability change: requires 2-reviewer approval          |
|                                                          |
| Notes [_________________________________]                |
|                                                          |
| [Reject] [Request changes]    [Approve & queue 2nd]     |
+--------------------------------------------------------+
```

## Motion
- Detail screen hero image parallax on scroll, max 8 px shift.
- Install button morphs to spinner then check, 280 ms total.
- Reviewer queue rows slide in 60 ms apart on load.

## Accessibility
- Star rating exposes `role="img"` with `aria-label="4.7 out of 5 stars, 1234 reviews"`.
- Price always paired with currency text, never icon alone.
- Reviewer keyboard shortcuts: J/K next-prev, A approve, R request changes, X reject; visible help via `?`.
- Capability list reused from Plugin System ensures consistent SR experience.

## Empty / Error States
- No purchases yet: illustration + CTA "Browse free themes".
- Payment failure: "Card declined. Try another card or wallet." with retry button, no jargon.
- Listing under review: gray banner "This listing is in review and not yet public."

## Dark Mode
- Reviewer console uses high-contrast dark by default; diff view uses semantic colors (added green, removed red, scope-changed amber) with text labels.
