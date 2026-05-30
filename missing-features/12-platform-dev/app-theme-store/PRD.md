# PRD: App & Theme Store

## Summary
A first-party storefront where developers and designers list plugins, themes, sticker packs, and sound packs for Flicko. Buyers pay with the existing flicko-pay wallet (Stripe-backed). Listings go through a review queue; reviewers approve, request changes, or reject. Reviews and ratings are first-class. Free items, paid one-time purchases, and per-server subscriptions are supported.

## Problem
Plugin System ships the runtime; we still need a place for users to find, evaluate, and buy add-ons, and for creators to make money. Without an integrated store, distribution happens on external Discord servers and GitHub READMEs, killing discovery and trust. We also leak revenue: third parties already sell Flicko bots on side channels with no quality bar.

## Jobs To Be Done
- As a server owner, I want to browse curated themes and try one in-server with one tap.
- As a creator, I want to publish a theme, set a price, and get paid in 30 days minus platform fee.
- As a member, I want to read honest reviews from other servers before installing.
- As a Flicko reviewer, I want a queue with diff view, capability changes, and a one-click approve/reject.
- As a finance owner, I want clear ledger lines per purchase, refund, and creator payout.

## In Scope
- Listing types: plugin, theme, sticker pack, sound pack.
- Free, paid one-time, subscription monthly/yearly.
- Review queue with reviewer roles, SLA timers, comment threads.
- Ratings (1 to 5 stars) and short reviews from servers that installed for at least 24 h.
- Featured collections, category browsing, search.
- Refund window 7 days for one-time purchases.
- Creator payouts via flicko-pay (Stripe Connect).
- Tax handling delegated to Stripe Tax.

## Out of Scope
- In-app gifting (v2).
- Bundle discounts (v2).
- Crypto payments.
- Hosting external creator sites.
- DRM beyond capability scoping (themes are public assets once installed).

## Success Metrics
1. 30% of monthly active servers visit the store at least once per month.
2. Average review queue time under 18 hours, p95 under 48 hours.
3. Creator payout error rate under 0.5%.
4. Refund rate under 4% of paid installs.

## Competitive Landscape
| Storefront | Review queue | Mobile | Subscriptions | Cut |
|---|---|---|---|---|
| Discord App Directory | Lightweight | Web only | No | n/a (free) |
| Slack App Directory | Manual review | Limited | Yes | 30% |
| Shopify App Store | Manual + auto | Yes | Yes | 0-15% |
| Apple App Store | Heavy review | Yes | Yes | 15-30% |
| Flicko Store (this) | Tiered (auto + manual on cap escalation) | Full mobile | Yes | 12% |

## Pricing
- Platform fee 12% of gross. Reduced to 8% after $1M lifetime gross per creator.
- Stripe processing passed through.
- Creators set their own currency from a 12-currency allowlist.

## Risks
- Card chargebacks; mitigate with Stripe Radar plus internal velocity checks.
- Asset hijacking by typosquatters; reserve names matching known brands, manual reservation form.
- Review queue backlog; SLA dashboard, escalation to on-call reviewer.
- Theme contains hateful artwork; community reporting + manual takedown SLA 24 h.

## Release Plan
- M1: catalog + listings DB + free-only flow.
- M2: payments via flicko-pay, paid one-time.
- M3: subscriptions + payouts.
- M4: reviews, ratings, featured slots.
- M5: GA launch event with curated bundle.

## Open Questions
- Subscription proration on upgrade.
- Whether to allow A/B priced regional offers at launch.
