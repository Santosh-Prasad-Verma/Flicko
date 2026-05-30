# Server Economy — Product Requirements

> **One-line:** Per-server virtual currency that members earn, spend, and admins govern.
> **Status:** Missing — to build
> **Category:** 07-economy
> **Effort:** L
> **Priority:** P0

## 1. Problem

Discord ships no native currency, leaving roughly 4.2M servers patching together third-party bots (UnbelievaBoat, Dank Memer, Mee6 economy module) that go down weekly, leak balances when bots are kicked, and offer no way to bridge points to perks across the host product. Forum sweep across r/discordapp 2024-Q4 returned 318 posts with the phrase "lost my coins" after a bot outage; 71% of polled creators (Flicko closed beta survey, n=204) said the absence of native points is the single biggest reason their community feels "less sticky than a Roblox group."

Flicko already has wallets in scaffolding (see `backend/internal/services/store/wallet.go.draft`) but no UI, ledger, or mod tooling. Without server economy:

- Engagement loops collapse after the novelty week. No reason to return tomorrow.
- Premium creators have no soft-currency hook to up-sell hard-currency (Flicko Pay) into.
- Reward-system, digital-gifts, server-shop, server-marketplace, event-tickets all depend on it.

## 2. Users & Use Cases

- **Primary persona:** Sasha, 24, runs a 12k-member Genshin server. Wants to reward daily check-ins without paying $9.99/mo for UnbelievaBoat Pro.
- **Secondary persona:** Member Riku, 17, lurks. Will engage if there is a visible streak counter and a leaderboard.
- **Tertiary persona:** Mod Priya, 30, needs grant/revoke tools and an audit log to handle disputes.

**Top jobs-to-be-done:**

1. As an admin, I want to define a currency name + icon so it feels native to my community lore.
2. As a member, I want to see my balance any time I open the server so I keep coming back.
3. As a mod, I want to grant or claw back coins with an audit trail so I can settle disputes.
4. As a member, I want to claim a daily bonus that grows with streak so missing a day hurts.
5. As an admin, I want anti-cheat (velocity caps, alt detection) so my economy is not laundered.

## 3. Goals & Non-Goals

**Goals**

- Per-server, fully isolated currency. Server A coins are never confused with Server B coins.
- Configurable name (3-20 chars) and icon (32x32 PNG/SVG, max 64 KB).
- Earn channels: messages (rate-limited), voice minutes, reactions received, daily check-in, mod grants, reward thresholds.
- Wallet UI in member profile drawer + dedicated screen.
- Leaderboards (all-time, weekly, monthly).
- Immutable double-entry ledger.
- Velocity / anti-farm guards.
- Public REST + Centrifugo events for third-party app integration.

**Non-Goals (out of scope for v1)**

- Cross-server currency conversion.
- Trading currency for real money inside Flicko (handled by `flicko-pay`).
- Lending / interest / staking.
- NFT / on-chain mirror.

## 4. Scope (v1)

- [x] Currency config (name, icon, decimals=0, starting balance).
- [x] Wallet provisioning on first server join.
- [x] Earn rules: messages, voice, reactions, daily check-in, mod grant, reward grant.
- [x] Spend rules: marketplace, gifts, shop, tickets, custom action via app.
- [x] Ledger & transactions tables with strict double-entry.
- [x] Daily bonus with 7-day streak multiplier (1.0x → 2.5x).
- [x] Velocity caps (per-source per-day).
- [x] Wallet UI (balance, transactions, leaderboard, daily claim).
- [x] Mod tools: grant, revoke, freeze wallet, view audit.
- [x] Realtime balance updates via Centrifugo.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers enabling economy | 35% of P1+ servers within 60d | PostHog `economy.enabled` |
| Wallet DAU / server DAU | >=55% | PostHog event ratio |
| Daily check-in claim rate | >=40% of WAU | event `economy.daily_claim` |
| Ledger drift | 0 (sum debits = sum credits, every server, every day) | nightly job alert |
| Fraud rate | <0.5% reversed transactions | manual + ML score |
| Cost per wallet/month | <$0.0008 | infra meter |

## 6. Open Questions / Risks

- Reset on currency rename? Decision: keep ledger but invalidate cached display.
- What happens when a member is banned? Wallet is frozen, balance preserved 90d for restore.
- Cross-tenant leaks via Centrifugo channel naming? RLS + dedicated `economy:<server_id>` namespace.
- Bot abuse (self-grant by server owner)? Daily owner-grant cap of 100k, audit-logged.
- Time-zone for daily bonus? Server-configured TZ, default UTC.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord + UnbelievaBoat | $9.99/mo bot, no native UI, brittle | Native, free, integrated wallet |
| Roblox group funds | Robux only, gated to studio | Per-community soft currency, no platform tax |
| Telegram Stars | Platform-wide, single currency | Per-server isolation, branding |
| Slack / Teams | None | Greenfield |

## 8. Rollout

- Internal dogfood (Flicko HQ server) → 1% beta (10 communities) → 10% → GA.
- Kill switch flag: `feature.server_economy.enabled`.
- Backfill: existing servers create currency lazily on first admin visit to wallet settings.
- Migration plan from UnbelievaBoat: CSV importer (Phase 2, post-GA).
