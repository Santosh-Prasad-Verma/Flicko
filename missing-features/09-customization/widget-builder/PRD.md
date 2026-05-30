# Widget Builder — Product Requirements

> **One-line:** Drag-drop builder for embeddable server widgets on websites.
> **Status:** Missing — to build
> **Category:** 09-customization
> **Effort:** L
> **Priority:** P2

## 1. Problem

Discord ships a single tiny widget (member online count + invite). Slack and Teams have nothing comparable. Communities running their own websites (gaming clans, indie game devs, study groups) want richer, brand-matched widgets to embed on their landing pages: events list, recent posts, leaderboard, member highlight reel.

Today they build custom apps against the API by hand or screenshot Discord. Flicko's wedge: a no-code drag-drop builder that emits an iframe `<script>` snippet. Components include member count, recent posts, event list, leaderboard, online roster, "join us" CTA. The output is a static, themable embed served over CDN at a per-server URL.

## 2. Users & Use Cases

- **Primary persona:** "Wren" — solo founder of an indie game studio, wants a "Join our Flicko" widget on the marketing site showing member count and the latest 3 posts.
- **Secondary personas:** community organizers; clan leaders; class TAs.
- **Top 3 jobs-to-be-done:**
  1. As a server owner, I want to drag widgets onto a canvas and copy a snippet, so I can paste it on my website.
  2. As a server owner, I want the widget to match my brand colors, so it looks native on my site.
  3. As a viewer, I want the widget to load fast and not break my page, so I'm not annoyed.

## 3. Goals & Non-Goals

**Goals**
- Visual builder with 8 widget types: member count, online roster, recent posts, event list, leaderboard, channel highlight, "join us" CTA, custom HTML-free banner.
- Theme: pick brand color + dark/light variants.
- Embed snippet works as `<iframe>` and as `<script async>`-loaded shadow DOM.
- Shareable preview URL.
- Server-side rendered first paint <500ms (data prefetched at edge).

**Non-Goals (out of scope for v1)**
- Arbitrary HTML / JS in the widget body.
- Authenticated views (private member info).
- Per-user personalization on the widget.
- Direct chat from the widget.

## 4. Scope (v1)

- [ ] Web app at `widget-builder/` (Vite + React) reachable from server settings.
- [ ] Drag-drop canvas (existing approach in `gaming-ui/` informs choices).
- [ ] 8 widget components, each themeable.
- [ ] Save layout to backend `embed_widgets` table.
- [ ] Edge renderer at `embed.flicko.app/<slug>` with strict CSP.
- [ ] Snippet generator: copy-pasteable `<iframe>` + `<script async>` flavors.
- [ ] Owner-only edit; public read.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers using widgets | 5% within 30d | DB count |
| Snippet copy events | 80% of created widgets | PostHog |
| Edge render p95 | <300ms | edge metric |
| Embed CSP violations | 0 | Sentry |
| Cost per widget request | <$0.00001 | edge logs |

## 6. Open Questions / Risks

- Should the renderer support dark detection? Yes — `prefers-color-scheme` honored automatically; theme override wins.
- Anti-iframe-busting? Frame-Ancestors CSP locked to allowlisted domains the owner sets.
- Rate limiting? 600 RPM per slug at edge.
- Where do we host the edge renderer? Cloudflare Worker initially; static HTML cached 60s.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | One widget, very basic | 8 widgets, drag-drop, branded |
| Slack | None | First-class |
| Trello | Power-Ups (custom widgets) | Different domain, but cleaner builder |
| Notion | Public pages | We add live-data widgets |

## 8. Rollout

- Internal dogfood (use on Flicko's own marketing site) → 10% beta → GA.
- Flag: `feature.widget_builder.enabled`.
- Snippet generator gated behind owner verification (server age >7d).
