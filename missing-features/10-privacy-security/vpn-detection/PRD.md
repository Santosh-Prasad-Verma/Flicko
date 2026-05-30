# VPN Detection — Product Requirements

> **One-line:** Detect VPN/proxy at signup and login; warn the user, never auto-block.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** S
> **Priority:** P2

## 1. Problem

Most platforms either ignore VPN traffic completely or punish it (bans, captchas, rate limits). Both extremes hurt users. People use VPNs for legitimate reasons every day: privacy, traveling, ISP throttling, jurisdictional protection, threat-actor avoidance. But unannounced VPN traffic is also the calling card of multi-account abuse, ban-evasion, and fraud.

Real evidence:
- Discord shadow-bans VPN-originating accounts; the user-experience is widespread frustration ("I just got back from vacation, why am I locked out?").
- Account-fraud reports cite IP-rotation as the #1 vector for new-account abuse on social platforms.
- Privacy advocates argue that any auto-block treats privacy-tooling users as criminals.

The pain: there is no honest middle ground today. Either the platform pretends VPNs don't exist (bad fraud signal) or it acts hostile (bad user experience).

## 2. Users & Use Cases

- **Primary persona:** All users at signup and login.
- **Secondary persona:** Trust & Safety team monitoring abuse correlations.
- **Top 3 jobs-to-be-done:**
  1. As a privacy-conscious user, I want to know my login looked unusual to Flicko, so that I can confirm and continue.
  2. As a T&S analyst, I want VPN signal in my fraud-investigation dashboard, so that I can correlate with other signals.
  3. As a user traveling abroad, I want to add a recovery factor before continuing, so that my account stays accessible.

## 3. Goals & Non-Goals

**Goals**
- Detect VPN/proxy via IP intelligence on signup and login.
- Show a warning banner: "Your connection looks like it's via VPN." Never auto-block.
- Store a privacy-preserving signal in `auth_security` for T&S to correlate.
- Offer the user a choice: continue, switch off VPN and retry, or contact support.

**Non-Goals (out of scope for v1)**
- Auto-blocking, shadow-banning, or rate-limiting based on VPN signal alone.
- Tor exit-node detection (separate, sensitive feature).
- Geolocation-based content restrictions.
- Storing the IP address itself long-term (we hash or truncate).

## 4. Scope (v1)

- [ ] Integrate VPNAPI free tier (or self-hosted MaxMind GeoIP2 anonymous-IP DB) at signup + login.
- [ ] Display warning banner when VPN detected; provide "Why am I seeing this?" explainer.
- [ ] Store `auth_security_events` row with hashed-IP, vpn_detected, country_code, asn.
- [ ] Add admin/T&S dashboard tile: "VPN signups in last 24h."
- [ ] Configurable threshold for showing 2FA prompt when VPN+new-device combined.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| VPN-detected logins/signups identified | accurate within ±5% of ground truth | manual sample |
| User abandonment at warning | <2% | event |
| Support tickets re VPN warning | <0.1% | tag |
| T&S correlation hits | trackable | dashboard |

## 6. Open Questions / Risks

- **Risk: VPNAPI free tier rate limits.** Mitigation: cache hot IPs 24h in Redis; degrade gracefully on quota exceed (skip detection, log warning).
- **Risk: false positives on residential proxies.** Mitigation: warning copy is non-accusatory; we say "looks like" not "is."
- **Risk: privacy of the IP itself.** Mitigation: store SHA-256 hash with daily salt rotation; truncate to /24 (IPv4) or /48 (IPv6) for analytics.
- **Open: do we offer a "trusted VPN" checkbox** for users who use a corporate VPN by default? Maybe in v2.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Silent shadow-ban | Transparent warning |
| Twitter/X | Unrestricted | We add safety signal |
| GitHub | None | Same |
| Bank apps | Block | We respect privacy |

## 8. Rollout

- Internal dogfood → 10% beta → 50% → GA.
- Kill switch: `feature.vpn_detection.enabled`.
- Provider failover: VPNAPI → MaxMind self-hosted → skip.
