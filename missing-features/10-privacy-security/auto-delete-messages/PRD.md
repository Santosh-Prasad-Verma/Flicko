# Auto-Delete Messages — Product Requirements

> **One-line:** Channel-wide TTL configured by mods; messages auto-delete after N hours/days.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** M
> **Priority:** P1

## 1. Problem

Some channels accumulate noise quickly: voice-chat lobby, intro-yourself, daily-standup, off-topic spam. Today the only options are manual cleanup by mods (impractical at scale) or third-party bots (Auttaja, Carl-bot) which require ad-hoc setup and break in unpredictable ways. There is no first-class channel-level retention setting.

This is distinct from `disappearing-messages` (per-message TTL chosen by sender). Auto-delete is mod-controlled and applies channel-wide regardless of sender intent. Together they cover both individual privacy and community hygiene.

Real evidence:
- Discord support requests for "auto-delete after 24h" cross 5k upvotes.
- Auttaja and Carl-bot offer this; both list "broken / brittle" complaints.
- Server admins of intro/standup channels routinely build cron-script bot stacks.

## 2. Users & Use Cases

- **Primary persona:** Server mods of high-volume channels who want a clean low-history baseline.
- **Secondary personas:** Community admins running ephemeral event channels; standup/voice-text channels.
- **Top 3 jobs-to-be-done:**
  1. As a mod of #general-chat, I want messages older than 7 days to auto-delete, so that the channel feels live and present.
  2. As a server owner, I want auto-delete grace period before any user message disappears, so that important content can be pinned.
  3. As a member, I want to know a channel auto-deletes, so that I do not waste effort on long messages.

## 3. Goals & Non-Goals

**Goals**
- Mod sets channel-wide TTL: 1h, 6h, 24h, 7d, 30d, off.
- Pinned messages exempt.
- System messages (joins, mod actions) exempt configurably.
- Visible "auto-delete" badge in channel header.
- Sweeper reuses the disappearing-messages worker pattern.
- Audit-log entries for retention changes (no content).

**Non-Goals (out of scope for v1)**
- Per-thread TTL (channel-level only).
- Selective TTL by message type (everything goes, except pins/system if configured).
- Custom TTL values beyond presets.
- Auto-archive instead of delete (separate roadmap item).

## 4. Scope (v1)

- [ ] Channel TTL config UI (mod-only).
- [ ] `channel_auto_delete_settings` table.
- [ ] Sweeper worker (extends `disappearing_messages` sweeper).
- [ ] Header badge.
- [ ] Composer hint when posting in auto-delete channel.
- [ ] Audit-log entries for retention-change events.
- [ ] Member-side surface: "this channel auto-deletes" first-time tooltip.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Channels enabling auto-delete | ≥4% of active channels within 90d | settings query |
| Sweep lag | <90s p99 | metric |
| Mod-reported "manual cleanup" | down 50% | survey |
| Member confusion ("where did my message go?") | <0.2% | tag |

## 6. Open Questions / Risks

- **Risk: surprised member.** They post then come back and message is gone. Mitigation: header badge + first-time tooltip + composer hint.
- **Risk: pin abuse.** Mods could pin to bypass; that is intended (pins are explicit retention).
- **Risk: legal-hold conflict.** Server admins must understand they are configuring permanent loss. Confirmation modal at setup.
- **Open: should member-side option exist?** v1 says no; only mods configure.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Bot-only | Native + reliable |
| Slack | Workspace-wide retention | Per-channel granularity |
| Telegram | Per-chat secret only | Per-channel mod-controlled |

## 8. Rollout

- Internal dogfood → 5% beta → 25% → GA.
- Kill switch: `feature.auto_delete_messages.enabled`.
- Per-server can be locked-off by admin.
