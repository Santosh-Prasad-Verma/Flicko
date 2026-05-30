# Regional Content Filters — Product Requirements

> **One-line:** Apply country-specific content rules (illegal symbols, gambling, age-gates) by user region.
> **Status:** Missing — to build
> **Category:** 14-localization
> **Effort:** L
> **Priority:** P0
> **Slug:** `regional-content-filters`

## 1. Problem

Different countries treat the same content very differently:
- **Germany** outlaws Nazi symbols (StGB §86a) — even meme usage attracts criminal liability.
- **South Korea** has strict gambling and youth-protection rules; loot-box odds must be disclosed; users under 19 can't access "adult-only" channels.
- **France** requires GDPR-style consent banners and forbids certain influencer content without disclosure.
- **United States** has DMCA, COPPA (under-13), and state-level adult-content rules.
- **China, Iran, UAE** outright ban categories (LGBTQ+ content, religious imagery, etc.) — we are not entering those markets but must not push prohibited push notifications to traveling users.
- **United Kingdom** Online Safety Act (2024) requires illegal-content takedown processes and age assurance for adult content.

Today, Flicko applies a single global moderation policy. To launch globally without legal exposure, we need a region-aware filter layer that applies on read and on write — letting an admin in one country see content that is forbidden in another, while *automatically* hiding (not deleting) the content for the protected region.

Real evidence:
- 7 GitHub issues from EU users requesting GDPR-compliant defaults.
- Discord faced a $1.4M Korean fine in 2023 over insufficient age verification.
- Stripe Atlas's compliance checklist for global SaaS lists 21 region-specific content rules.

## 2. Users & Use Cases

- **Primary persona:** "Klaus in Berlin" — should never see banned symbols in his Flicko feed; if a NA user posts one, Klaus's view auto-hides it.
- **Secondary personas:** server admins (need clarity on what's hidden); compliance officers (audit trail); content moderators (region-aware queue).
- **Top jobs-to-be-done:**
  1. As a German user, I want banned symbols filtered out automatically, so that I have legal cover.
  2. As a server admin, I want a clear UI showing "this message is hidden for {region} viewers because of {rule}".
  3. As a compliance team, I want every filter decision logged with rule_id, so that audits are easy.
  4. As a Korean parent, I want my under-19 child auto-blocked from age-restricted content (loot-box channels, NSFW).

## 3. Goals & Non-Goals

**Goals**
- `region_rules` table with country code → rules JSON (e.g. `DE → ban_nazi_symbols`).
- Read-side middleware filters messages and channels per viewer's region.
- Write-side soft-warning when a user posts content that will be filtered for someone.
- Region detected from IP (CloudFlare header) on first session, persisted to profile, override-able.
- Age assurance for restricted content (KR, UK): birth-date prompt with flag-don't-store-DOB option.
- Audit log of every filter action (`region_filter_audit`).
- Admin tool: rules editor (only Flicko employees) and per-server overrides.

**Non-Goals (out of scope for v1)**
- Government takedown request handling (separate workflow, separate spec).
- Real-time machine-learning content classification — we use deterministic rules first, ML later.
- Geo-blocking at the network level (we filter content, not access).
- Content removal — we *hide* for affected region, never silently delete.

## 4. Scope (v1)

- [ ] `region_rules` table + `region_rule_assignments` (rule × region)
- [ ] Region detection middleware (`X-Country` from Cloudflare; fallback IP geo)
- [ ] Filter chain (regex match, hash match, attribute match)
- [ ] Read-side filter: messages, channel descriptions, server names, voice channel topics
- [ ] Write-side warning: pre-send classifier flags problematic content with explainer
- [ ] Age-assurance flow (per region): KR (>=19), UK (>=18 for adult), US (>=13 COPPA)
- [ ] Admin rules editor in `admin/regional-rules`
- [ ] Audit log + Sentry breadcrumb on every hide
- [ ] Per-server override (admin can choose stricter, never looser, than region default)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Filter false positive rate | <0.5% | manual sample audit |
| Compliance bug reports | 0 P0 | bug tracker |
| Region detection accuracy | ≥98% | A/B with self-reported |
| Time-to-block new rule | <1h | rule deploy → live |
| Audit completeness | 100% filter events logged | sampling |
| Cost | $0 | n/a |

## 6. Open Questions / Risks

- VPN users: what's their "real" region? We trust profile override for that user only; track for fraud.
- Conflict between server admin's region and viewer's region: viewer's region wins.
- "Stricter" definition: one-way ratchet — admin can add restrictions, never remove a region's default.
- DOB privacy: we never store actual DOB; only `is_18_plus`, `is_19_plus`, `is_13_plus` flags computed at attestation time.
- Free-speech tension: we are transparent — every hidden message shows a generic "hidden for your region" indicator that the user can tap to learn more.
- Sanctioned countries (Cuba, Iran, North Korea, Crimea, Sudan, Syria): we don't route to them at all — no content filter applies because no service applies. This is OFAC, not content rules.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Limited region-specific rules; mostly global moderation | We expose rule taxonomy to server admins |
| Reddit | Country-specific bans on subreddits | We do per-message granularity |
| Twitter/X | Country-Withheld Content (CWC) banner | We model after CWC |
| YouTube | Region availability + age gates | We adopt age-gate UX |
| Twitch | Limited; mostly via DMCA | We offer transparent rule list |

## 8. Rollout

- Phase 1: rules engine in shadow mode (logs hits, doesn't filter) — internal dogfood.
- Phase 2: enable filtering for DE-Nazi-symbols, KR-gambling-disclosure, UK-adult-age.
- Phase 3: enable additional rules per region as they pass legal review.
- GA: when DE/KR/UK/FR rules pass legal sign-off and false-positive rate stays <0.5%.
- Kill switch: `feature.regional_content_filters.enabled` (off = no filtering, full audit). Per-region: `feature.regional_content_filters.regions.<code>.enabled`.

## 9. Legal & Compliance Notes

- This feature reduces legal exposure but does not eliminate it. Legal review required for every new rule before activation.
- Transparency report: quarterly published filter actions per region (counts only, no PII).
- DPIA (Data Protection Impact Assessment): performed before EU rollout.
- Right of explanation (GDPR): tapping a hidden item shows the rule_id and a brief description.
