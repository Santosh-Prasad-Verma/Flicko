# Anonymous Mode — Product Requirements

> **One-line:** Join servers under a per-server pseudonym while mods retain ban power.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** L
> **Priority:** P0

## 1. Problem

Discord forces every member to expose the same global username across every server they join. A user who lurks in a survivor-support server, a fandom server, and their workplace community is the same `@taylor_2024` everywhere — searchable, bridgeable, doxx-able. Privacy-conscious users juggle alt accounts, but Discord's TOS forbids alts and the alt itself leaks fingerprints (avatar reuse, friend graph, voice).

Real evidence:
- r/discordapp threads on "burner usernames" reach the front page roughly once a quarter.
- The 2025 Stanford "platform identity" study showed 41% of marginalized-community members on Discord run alts purely for compartmentalization.
- Trust & Safety teams in support servers (mental health, abuse recovery, LGBTQ+) have publicly asked for "throwaway-mode joins."

The pain: identity bleed across communities. The constraint: mods must still be able to ban, mute, and report — anonymity that breaks moderation is worse than no anonymity.

## 2. Users & Use Cases

- **Primary persona:** A community member with multiple distinct social contexts who wants to participate authentically without cross-server identity bleed.
- **Secondary personas:** Mods of sensitive support servers; whistleblower-style community admins; minors whose parents do not want their handle indexed.
- **Top 3 jobs-to-be-done:**
  1. As a survivor-support member, I want to post under a stable pseudonym, so that nobody from my workplace server can find me.
  2. As a server mod, I want to ban an anonymous troll permanently, so that they cannot rejoin even after changing their handle.
  3. As a privacy-conscious gamer, I want to switch between "real" and "anon" identities per server, so that my main account stays clean.

## 3. Goals & Non-Goals

**Goals**
- Per-server anonymous handle generated at join, stable for the duration of membership.
- Mod tooling can ban / mute / report referencing the anon handle; under the hood the action keys off an HMAC of `(server_id, user_id)` so re-joining with a fresh handle still hits the ban.
- Direct messages and friend graph remain hidden from the anonymous-server context.
- Audit log records the HMAC, never the underlying user_id, for any mod-visible surface.

**Non-Goals (out of scope for v1)**
- Anonymity from Flicko itself — we still know who you are; this is identity-shielding from other members and mods.
- Anonymous voice (separate feature: `encrypted-voice`).
- Anonymous account creation — still requires a verified Flicko account.
- Cross-server pseudonym pooling (each server gets a fresh handle).

## 4. Scope (v1)

- [ ] Toggle in server-join flow: "Join as Anonymous" (server must opt in to allow it).
- [ ] Auto-generated handle: adjective+noun+4digits, e.g., `QuietFox4218` — verified unique within server.
- [ ] HMAC-based internal identity for mod actions, audit log, and ban list.
- [ ] Anon members hidden from member list export, friend suggestions, and global search.
- [ ] Mod-side: ban, mute, kick, timeout, report all work referencing anon handle; the mod sees `QuietFox4218` and the ban hash, never the real user.
- [ ] User-side: per-server "reveal me" button (one-way, irreversible) for users who change their mind.
- [ ] Server-setting: "Allow anonymous joins" (default off; owner toggles on).

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers enabling anon-mode | 5% of public servers within 90d | server_settings query |
| Anon joins per enabled server | ≥10% of new joins | join-event analytics |
| Re-ban evasion rate | <3% of bans bypassed | ban-hash collision audits |
| Reveal-me usage | <2% of anon members reveal within 30d | event |
| Support tickets re anon mode | <0.5% of total | Zendesk tag |

## 6. Open Questions / Risks

- **Risk: weaponized anonymity** — anon users harassing then disappearing. Mitigation: HMAC ban + rate-limited joins + reputation-floor (account >=14d old to use anon).
- **Risk: legal disclosure** — court order asks "who is QuietFox4218?" Answer: we can resolve via HMAC reverse lookup; document this in the privacy policy and threat model.
- **Open: should anon users be excluded from XP/levels?** Likely yes; otherwise leaderboards leak.
- **Open: avatar policy** — generate a deterministic avatar from the HMAC, or let user upload? V1: generated only; uploaded avatars are an identity vector.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Single global username; no anon mode | Per-server pseudonym natively |
| Reddit | Anon-by-default; alt-friendly | Reddit can't do voice/realtime; we can |
| Slack | Profile per workspace, but tied to email | Email is the leak; we hide it |
| Matrix | Pseudonymous already (room display names) | UX is hostile; we make it one tap |

## 8. Rollout

- Internal dogfood (Flicko staff support server) → 1% of opt-in servers → 10% → GA.
- Kill switch flag: `feature.anonymous_mode.enabled`.
- Per-server flag also acts as kill switch at server granularity.
- Support article + privacy-policy update must ship simultaneously with GA.
