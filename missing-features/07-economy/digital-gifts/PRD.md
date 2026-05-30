# PRD - Digital Gifts

## Summary
Digital Gifts are low-cost in-app collectibles (animated stickers, fireworks, hearts, custom skins) that users send to creators or friends inside chat, voice, stage, or video calls. Each gift has a Flicko Coin price, a cosmetic effect on the receiving surface (chat overlay, screen-fill animation), and a revenue split between the platform, the receiving creator, and optionally the host server. Gifts run on a prepaid Flicko Coin balance funded via Flicko Pay so we control velocity and avoid per-gift Stripe fees.

## Problem
Live engagement on text/voice/video has no expressive monetary signal. Twitch Bits, TikTok coins, YouTube Super Stickers proved that fans want to spend on emotion, not just access. Without it, creators on Flicko cannot earn during live moments and viewers cannot stand out. Direct one-tap Stripe charges are too expensive (30c fixed fee crushes < $1 gifts) and too slow (3DS friction destroys impulse spend).

## Jobs To Be Done
- As a **viewer in a stage**, when a creator says something I love, I want to send a flashy reaction in 1 tap, so they see my appreciation in front of everyone.
- As a **creator on stream**, when a gift lands, I want a delightful screen animation with the sender's name, so the audience sees momentum and joins in.
- As a **fan**, when I top up coins, I want bulk discounts for committing more, so I feel like an insider.
- As **finance**, when coins are spent, I want each spend ledgerized to creator payable balance, so payouts are correct.

## Scope
In: gift catalog (animated lottie/rive packs), Flicko Coins balance, top-up via Stripe (one-time), send gift in chat/voice/stage/video, creator gift inbox, animated overlays, leaderboards, refund of unused coin balance, anti-fraud velocity caps.
Out (v1): trading gifts between users, NFT gifts, physical gift redemption, multi-currency coins.

## Metrics
- ARPPU (avg revenue per paying user) >= $4.20 / month.
- Gift send rate >= 0.7 gifts per active session in stages.
- Coin top-up retention (D30 of paid users top up again) >= 41%.
- Refund/dispute rate <= 1.0% of GMV.

## Competitive Table
| Surface | Coin economy | Animated overlays | Server share | Max single gift | Take rate |
|---|---|---|---|---|---|
| Twitch Bits | Yes (Bits) | Cheers | No | 100k Bits | 50% creator |
| TikTok Coins | Yes | Yes | No | $500 | 50% creator |
| YouTube Super Stickers | No (one-shot) | Yes | No | $500 | 30% platform |
| Discord Soundboard tips | No | Limited | No | n/a | n/a |
| Flicko Gifts | Yes (Coins) | Yes (lottie/rive) | Yes | $200 single (config) | 30% platform / 5% server / 65% creator |

## Risks
- Underage spend (mitigation: parental controls, hard daily cap, KYC for big spenders).
- Money-laundering via gift -> creator payout (mitigation: KYC tier, velocity caps, AML monitor).
- Apple/Google IAP conflict on coin top-ups (mitigation: web/PWA top-up only on iOS to avoid Apple's 30%; in-app coin top-up uses Apple IAP at parity but lower coin yield).
- Coin liability accounting (mitigation: coins are unredeemed-revenue liability per ASC 606 until spent or refunded).

## Open Questions
- Coin pegging: 100 coins = $1.00 fixed, or float? (Lean: fixed peg.)
- Apple IAP: implement or block? (Required by App Store, must implement with reduced yield.)
- Allow gifting outside stages (in DMs)? (Lean: yes, but smaller animations.)
