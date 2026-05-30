# PRD - Creator Subscriptions

## Summary
Creator Subscriptions lets creators offer recurring monthly or yearly tiers (Bronze/Silver/Gold style or named) that gate access to private channels, exclusive content drops, role badges, and DM access. Subscriptions are billed via Stripe Connect Express recurring invoices, settled to the creator's connected account net of platform and server cuts, and reconciled to the Flicko ledger. The system handles trials, proration, dunning, gifts, and cohort-based discount codes.

## Problem
Creators on Discord migrate to Patreon to earn predictable income, fragmenting their audience. Patreon takes 8-12% and provides no in-app voice/text continuity. There is no way for fans to see "subscribed" badges in chat, no native gating of channels by tier, and no programmatic role assignment that survives subscription state changes. Creators waste hours running Zapier glue between Patreon, Discord bots, and email. They also lose 5-15% revenue to involuntary churn (failed cards) because dunning is manual.

## Jobs To Be Done
- As a **creator**, when I publish a new tier, I want it to feel like an in-app product not an external link, so my audience converts at the speed of intent.
- As a **subscriber**, when I upgrade or downgrade, I want fair proration and instant role updates, so I never feel cheated.
- As a **creator**, when a card fails, I want automated dunning with smart retries before cancelling, so I keep more revenue.
- As a **server owner** hosting a creator, I want a configurable cut of every subscription generated under my server, so I am incentivized to amplify the creator.
- As **finance**, I want every subscription invoice ledgerized with fee/cut breakdown, so MRR/ARR is auditable.

## Scope
In: monthly/yearly tiers, free trial 7/14/30 days, gift subscriptions (single+bulk), promo codes (% or absolute), proration on upgrade/downgrade, cancel-at-period-end, dunning with smart retries, churn analytics, role/channel gating, reconcile to ledger.
Out (v1): pay-per-post, multi-currency switching mid-subscription, on-platform tipping, NFT-gated tiers, family plans.

## Metrics
- Active subscriber growth >= 12% MoM in first two quarters.
- Involuntary churn <= 4.5% monthly (Stripe baseline 6.5%).
- Net Revenue Retention >= 102% within 6 months of GA.
- Trial -> paid conversion >= 38%.

## Competitive Table
| Surface | In-app gating | Trials | Smart dunning | Gifting | Platform fee |
|---|---|---|---|---|---|
| Patreon | No (link out to Discord) | Yes | Basic | Yes | 8-12% |
| Ko-fi Memberships | No | No | No | No | 5% |
| YouTube Memberships | Per-channel | No | Yes | Yes | 30% |
| Twitch Subs | Per-channel | No | Yes | Yes | 50% |
| Flicko Subscriptions | Yes (server channels + DMs + roles) | Yes (configurable) | Yes (Smart Retries) | Yes | 5% + Stripe fees |

## Risks
- Card aging: Stripe Smart Retries help but card-on-file expiry will cause involuntary churn (mitigation: Stripe Card Updater + 7-day pre-expiry reminders).
- Refund disputes for content quality (mitigation: 7-day no-questions refund window prominent in UI).
- Tax compliance globally (mitigation: Stripe Tax with creator-tier subscription threshold review).
- Creator fraud: laundering via subscriptions to self (mitigation: same-IP/device velocity, KYC tier gates).

## Open Questions
- Allow creators to set their own server cut, or does the server owner enforce it? (Lean: server owner sets, creator sees, no negotiation in v1.)
- Yearly billing offered as second tier line or as toggle in same tier? (Lean: toggle, with default 17% discount baked in.)
- Trial across re-subscriptions? (Lean: trial only on first ever subscription per creator per user.)
