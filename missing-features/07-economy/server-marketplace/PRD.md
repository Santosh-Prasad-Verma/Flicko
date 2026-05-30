# PRD - Server Marketplace

## Summary
Server Marketplace is a per-server commerce surface where server owners and approved creators list digital and physical goods (cosmetics, role packs, merch, services, source files) for their members to purchase. Listings live inside the server context, support fixed-price and auction formats, and route payments through Flicko Pay (Stripe Connect Express) with revenue share to the server treasury. The Marketplace is the first monetization primitive that makes a server feel like a self-contained economy and is the seed surface for every other module in 07-economy.

## Problem
Server owners on Discord-style platforms have no native way to sell access, cosmetics, or merch to their community. They route members to Gumroad, Shopify, Whop, or DMs - which fragments analytics, breaks attribution, increases fraud, and leaves 10-25% of fees on the table. Creators cannot see who bought what without manual reconciliation, and members cannot trust unknown external checkouts.

## Jobs To Be Done
- As a **server owner**, when a member shows intent to support, I want a one-tap in-context checkout, so I capture revenue before the user leaves the app.
- As a **creator**, when I publish a new pack, I want to gate access tiers and bundle them, so I can ladder pricing without external tooling.
- As a **member**, when I buy a role pack, I want it to apply instantly and be visible on my profile, so the purchase feels native.
- As a **moderator**, when a listing violates policy, I want a one-click takedown with refund queue, so abuse does not snowball.
- As **finance**, when I close the books, I want every cent reconciled to a ledger row, so reporting is audit-grade.

## Scope
In: digital listings (roles, badges, source files, presets), physical listings (POD merch via Printful), auction listings, scheduled drops, refunds, disputes, takedowns, RLS per server, idempotent purchases, webhook reconciliation, server-level revenue share split.
Out (v1): cross-server listings, multi-currency outside USD/EUR/GBP/INR, NFT/crypto rails, rentals, secondary marketplace.

## Metrics
- GMV per active server >= $180/month within 90 days of launch.
- Checkout conversion (intent -> succeeded payment_intent) >= 62%.
- Refund rate <= 2.4% of GMV (Stripe baseline 1.8% for digital).
- p95 listing -> purchasable latency <= 6s including media transcode.

## Competitive Table
| Surface | In-app checkout | Auctions | Server rev-share | KYC tier | Take rate |
|---|---|---|---|---|---|
| Discord Server Shops | No (external) | No | Manual | None | 0% (host pays) |
| Whop | Yes | No | No | Stripe std | 3% + 30c |
| Gumroad | Redirect | No | No | Their merchant | 10% |
| Patreon Shops | Yes | No | No | Their merchant | 8-12% |
| Flicko Marketplace | Yes (native) | Yes | Yes (configurable 0-30%) | Stripe Express + tiered | 5% + 30c |

## Risks
- Stripe Connect Express onboarding friction (mitigation: allow draft listings before KYC, block payouts not listings).
- Chargeback liability on physical goods (mitigation: route physical via Printful merchant of record where possible).
- Tax nexus across regions (mitigation: Stripe Tax + threshold alerts in admin).
- Marketplace becoming an accidental securities offering (mitigation: ToS forbids revenue-share-as-investment, automated keyword scan on listings).

## Open Questions
- Do we surface a global discovery feed or keep listings strictly server-scoped in v1? (Decision: server-scoped, discovery in v1.1.)
- Auction min-increment policy: percentage or absolute? (Lean percentage 5%.)
- Refund window default: 24h / 72h / 14d? (Lean 72h for digital, 14d for physical per consumer law.)
