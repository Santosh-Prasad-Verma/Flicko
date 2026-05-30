# User Leaderboards Native — Product Requirements

> **One-line:** Native per-server XP leaderboards for messages, voice minutes, and helpfulness.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** M
> **Priority:** P1

## 1. Problem

Activity leaderboards are one of the top-installed bot categories on Discord and on Flicko (MEE6, Tatsu, Arcane). Bots are flaky, owner-hostile (paywalls), and produce inconsistent metrics. Owners want a clean, native leaderboard tied to first-class events. Members want recognition without grinding bot commands.

Evidence:
- 2025 owner survey: 62% use a third-party leaderboard bot
- MEE6 paywalls "level reset" feature; many owners frustrated
- Top-50 most-active members on a typical server account for 38% of messages

## 2. Users & Use Cases

- **Primary persona:** Server owner who wants community recognition without a bot
- **Secondary personas:** member checking own rank, mod investigating gaming behavior
- **Top 3 jobs-to-be-done:**
  1. As an owner, I see Top 50 members by activity this month
  2. As a member, I see my rank and what would move me up
  3. As an owner, I tune XP weights and exclude channels

## 3. Goals & Non-Goals

**Goals**
- XP ledger with sources: messages, voice minutes, reactions received, helpful votes
- Per-server rule config (weights, excluded channels, decay)
- Multiple time windows: today, 7d, 30d, all-time
- Visual rank list with progress bar to next level
- Badges and milestones at 5, 10, 25, 50 levels
- Anti-abuse: cooldowns, spam detection, voice afk filter

**Non-Goals (out of scope for v1)**
- Cross-server XP
- Custom level rewards (role rewards) — defer
- Real currency or paid boosts

## 4. Scope (v1)

- [ ] `xp_ledger` append-only events
- [ ] `xp_balances` per-user-per-server materialized
- [ ] `xp_rules` per-server config
- [ ] Background recompute on rule change
- [ ] Member detail with breakdown
- [ ] Top 50 list paginated
- [ ] Badges at level milestones

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers with leaderboard enabled | >=40% within 90d | DB |
| Bot replacement rate | -25% installs of MEE6/Tatsu | telemetry |
| Member self-rank views | >=2/week per active member | event |
| Cost per user/mo | <$0.0006 | infra |

## 6. Open Questions / Risks

- Should there be a "career" all-time mode that resists decay? Yes, parallel to seasonal
- Risk of XP grinding via spam: rate-limited XP per minute, anti-spam classifier later
- Voice afk: skip XP if user muted or no audio activity for >5m

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| MEE6 | Bot, paywall | Native, free |
| Tatsu | Bot | Native |
| Arcane | Bot | Native |
| Discord | None native | Greenfield |

## 8. Rollout

- Internal dogfood week 1
- 1% beta servers week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.user_leaderboards_native.enabled`
