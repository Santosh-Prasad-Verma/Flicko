# Achievement System — PRD

**Summary:** Server-defined Flicko achievements (community, voice, gaming, social) with a profile shelf, rarity tiers, and progressive unlocks that drive daily retention without per-game integrations.

## Problem

Flicko has a stickiness gap versus Discord: users join, send a few messages, and churn at 30 days. There is no intrinsic loop rewarding ongoing participation. Adding per-game achievements is intractable (every title differs); but a global, server-defined achievement layer is achievable, free, and scales horizontally.

The system must:
- Reward voice minutes, messages, clips, friend invites, gaming sessions, esports watch time.
- Display a curated shelf on every profile (top 6 pinned + scrollable rest).
- Trigger satisfying unlock animations without becoming spam.
- Run on free infrastructure (Postgres counters, Redis windows, batch cron).

## JTBDs

1. As a player, when I do something noteworthy on Flicko, I want a tangible badge so my profile reflects my history.
2. As a curator of my profile, I want to pin my best 6 badges so visitors see what I am proud of first.
3. As a server owner, I want server-scoped achievements (e.g. "100 voice hours in this server") to drive loyalty.
4. As a returning user, I want progress bars on locked achievements so I know what is reachable.
5. As a casual user, I want a daily-reachable achievement so I see progress every session.

## Scope

**In scope (v1):**
- 60 global Flicko achievements across 6 categories: Voice, Text, Social, Gaming, Esports, Veteran.
- 4 rarity tiers: Common (grey), Rare (blue), Epic (purple), Legendary (gold).
- Server-scoped achievements (server owners pick from a 20-template catalog).
- Profile shelf: 6 pinned + paginated rest.
- Unlock toast + optional confetti.
- Hidden achievements (revealed on unlock).

**Out of scope (v1):**
- Per-game in-title achievements (handled by `game-stats-integration` linked accounts).
- User-authored custom achievements.
- Tradable / NFT badges.
- Leaderboards (separate feature).

## Metrics

| Metric | Target | Measurement |
|---|---|---|
| D30 retention lift | +8 pp vs control | A/B over 6 weeks |
| Median achievements per MAU | >= 4 | DB count / MAU |
| Profile-view -> profile-view-with-shelf-click | >= 22% | client analytics |
| Unlock-toast -> shelf-pin rate | >= 15% | event funnel |

## Competitive table

| Platform | Server-defined | Per-game | Profile shelf | Rarity tiers | Server-scoped | Cost |
|---|---|---|---|---|---|---|
| Discord | No | No | No (badges only) | No | No | n/a |
| Steam | Limited | Yes | Yes | Yes (% rarity) | No | Per-game |
| PSN/Xbox | No | Yes (trophies) | Yes | Yes | No | Per-platform |
| Guilded | Partial | No | Partial | No | Partial | Free |
| **Flicko v1** | Yes | Via linked accts | Yes | Yes | Yes | $0 |

## Risks

- **Inflation:** trivial achievements devalue the shelf. Mitigation: rarity gated by global unlock %; legendary capped at <2%.
- **Counter drift:** double counts on retries. Mitigation: idempotency keys per event.
- **Spam on import:** user with 3y history gets 30 unlocks at once. Mitigation: silent-import flag suppresses toasts on backfill.

## Open questions

- Should achievement progress be public or private by default? (Lean: public for unlocked, private for in-progress.)
- Do we want seasonal achievements (rotating quarterly)? Probably yes in v1.1.
