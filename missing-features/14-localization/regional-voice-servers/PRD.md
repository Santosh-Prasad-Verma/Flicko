# Regional Voice Servers — Product Requirements

> **One-line:** Auto-pick the lowest-latency Azure ACS region per call so voice/video feels instant globally.
> **Status:** Missing — to build
> **Category:** 14-localization
> **Effort:** L
> **Priority:** P0
> **Slug:** `regional-voice-servers`

## 1. Problem

Today Flicko's Azure ACS cluster runs in a single region (US-East). For a Tokyo user joining a stage, audio round-trips ~250ms each way; mouth-to-ear delay exceeds 500ms — perceived as "broken" by anyone who's used Discord (~80ms regional) or Zoom (~120ms regional). The fix is multi-region Azure ACS deployments with smart selection per call.

Real evidence:
- 22 Sentry events per day tagged `voice.high_latency` from APAC IPs.
- A/B test on a sister project: per-region voice cut "audio quality" complaint volume by 76%.
- Server-side voice metrics show 240ms median p50 for IN/JP/SG users.

## 2. Users & Use Cases

- **Primary persona:** "Yuki in Tokyo" — joins Stage with friends in NA and EU; expects sub-150ms latency to *her* nearest hop.
- **Secondary personas:** any user on voice/video; admins running Stage events; gamers in voice channels.
- **Top jobs-to-be-done:**
  1. As a global user, I want voice to feel local, so that conversation is fluid.
  2. As a server admin, I want a session to use the lowest aggregate-latency region for all participants, so that the "weakest link" rule still gets a good experience.
  3. As infra, I want auto-failover if a region degrades, so that no user gets stuck.

## 3. Goals & Non-Goals

**Goals**
- Deploy Azure ACS nodes in five regions: NA-East (us-east), NA-West (us-west), EU (eu-west), APAC (ap-southeast), LATAM (sa-east), SEA (ap-south).
- Auto-pick lowest-latency region per call based on participant ping tests.
- Ping test runs on call-join (lightweight HTTP HEAD with TLS handshake to each region's edge).
- Voice room federation when participants span regions — so a Tokyo user and a New York user can land in their respective edges and the federation bridges them.
- Override hooks: server admin can pin region; user can manually select.
- Health-check + auto-failover: a degraded region drops out of the candidate pool within 60s.
- Metrics: per-region latency, packet loss, sessions, MoS scores.

**Non-Goals (out of scope for v1)**
- Edge MCU/SFU optimization beyond Azure ACS's defaults.
- Hardware-level codec choice — Azure ACS handles Opus/VP9 already.
- Self-hosted TURN beyond what Azure ACS ships.
- Latency optimization for non-voice (chat, push) — they don't need it.

## 4. Scope (v1)

- [ ] Deploy Azure ACS clusters in 6 regions (one shared infra repo `infra/azure_acs/<region>/`).
- [ ] Region picker library `regional_voice_picker.go` (server-side helper).
- [ ] Mobile ping test: HEAD `/health` to each region's edge in parallel, take fastest 3.
- [ ] Voice room creation API accepts region hint or uses score.
- [ ] Federation between regions for cross-region participants.
- [ ] Health-check endpoint per region; central registry in DB updated every 30s.
- [ ] Manual override (server admin) and per-user override.
- [ ] Voice settings UI showing currently-connected region.
- [ ] Failover: if connection drops, mobile auto-retries the second-best region.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Median voice p50 latency | <100ms global | Azure ACS server metrics |
| Per-region p99 latency | <150ms within region | server metrics |
| Auto-failover time | <5s after degraded detection | observability |
| Region selection accuracy | ≥95% (chosen = optimal in retrospect) | post-call analysis |
| Voice complaint volume | -70% vs baseline | support tickets |
| Cost increase | <2x baseline | infra invoices (Azure ACS Cloud pricing) |

## 6. Open Questions / Risks

- Azure ACS Cloud (managed) charges per minute per participant; multi-region adds federation cost. Need pricing model. Self-host on Hetzner / Fly.io edge nodes likely cheaper at scale.
- Federation is still maturing; some quirks with simulcast across regions. Mitigation: stage rollout starting with same-region calls only, then federated.
- Latency to a region is not the only quality factor — packet loss matters more for voice. Score must combine RTT + loss.
- Privacy: a Korean user might prefer a Korean-domestic region for data residency; we can't legally use US edges for KR users in some sectors. Address via region opt-in.
- TURN relay fallback: when P2P fails, we still need a relay near the user — we use Azure ACS's built-in TURN per region.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | 13+ voice regions, manual + auto pick | Match auto, simpler UI |
| Slack Huddles | 3-4 regions; auto only | Match auto + more regions |
| Zoom | Many regions, auto-pick + manual | Match auto |
| Teams | Anycast routing | We use BGP-anycast on Azure ACS edges if needed |
| Element Call (Matrix) | Azure ACS-based, federation early | We outperform with smarter scoring |

## 8. Rollout

- Phase 1: deploy NA-East + NA-West only; user choice manual; auto-pick disabled.
- Phase 2: enable EU; auto-pick within US/EU.
- Phase 3: APAC + SEA; federation enabled.
- Phase 4: LATAM; full GA.
- Kill switch: `feature.regional_voice_servers.enabled` (default ON post-GA); falls back to single us-east region.
- Per-region kill: `feature.regional_voice_servers.regions.<code>.enabled` for emergency drains.

## 9. Cost / Vendor Notes

- **Azure ACS Cloud** has multi-region; cost scales per minute.
- Alternative: self-hosted on **Hetzner** (FSN, NBG, ASH, HKG, SIN, SAO regions available) with **Coturn** — cheap but ops-heavy.
- v1 plan: Azure ACS Cloud Free (~10 minutes audio/video bundled), upgrade to Build plan ($50/mo + usage) before public launch.
- Edge ping endpoints can be hosted on **Cloudflare Workers** (free tier) with KV-cache last-seen-up flag — zero infra cost for the picker side.
