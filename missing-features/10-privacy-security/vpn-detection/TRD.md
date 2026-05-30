# VPN Detection — Technical Requirements

## 1. Architecture Overview

```
   ┌────────┐    signup/login    ┌────────────────┐
   │ Mobile │───────────────────▶│  Auth Handler  │
   └────────┘                    └────────┬───────┘
                                          │
                                          ▼
                              ┌──────────────────────┐
                              │  VPN Detector Svc    │
                              │  (services/privacy/  │
                              │   vpn_detection)     │
                              └─────┬───────────┬────┘
                                    │           │
                  Redis cache       │           │  cache miss
                                    ▼           ▼
                            ┌───────────┐ ┌────────────────┐
                            │ vpn:ip:   │ │ Provider:      │
                            │ <hash>    │ │ VPNAPI free    │
                            │ TTL 24h   │ │ or MaxMind     │
                            └───────────┘ │ Anonymous-IP   │
                                          │ DB (self-host) │
                                          └────────────────┘
                                    │
                                    ▼
                          ┌──────────────────────┐
                          │ auth_security_events │
                          │ (hashed IP, signal)  │
                          └──────────────────────┘
```

## 2. Components

### Backend (Go)

- **Service:** `internal/services/privacy/vpn_detection/service.go`
  - `Detect(ctx, ip) (*Detection, error)` — returns `{is_vpn, asn, country, source}`.
- **Provider abstraction:** `internal/services/privacy/vpn_detection/provider.go`
  - `interface Provider { Lookup(ctx, ip) (*Detection, error) }`.
  - Implementations: `VpnApiProvider`, `MaxmindProvider`, `NoopProvider` (fallback when both fail).
- **Cache layer:** Redis with hashed IP key.
- **Hook:** auth handlers call detector inline, attach result to session.

### Mobile (Flutter)

- **Feature folder:** `mobile/lib/features/privacy/vpn_detection/`
  - `application/`: `vpnDetectionResultProvider`
  - `presentation/`: `VpnWarningBanner`, `VpnExplainerSheet`
- Hook into auth flow: after a successful login response that carries `vpn_detected: true`, render banner.

### Infra
- Provider: VPNAPI free tier (1k requests/day) primary; MaxMind GeoIP2 Anonymous-IP DB fallback.
- Cache: Redis `vpn:ip:<sha256>` 24h TTL.
- DB: `auth_security_events` log table.

## 3. API Contracts

### REST (extension of existing auth)
```
POST /api/v1/auth/login
   response augmented:
   { ..., security: { vpn_detected: bool, country: "..", asn: ".." } }

POST /api/v1/auth/signup
   response augmented as above
```

VPN signal lives in the same response so the client renders the banner immediately. No separate endpoint.

## 4. Permissions & Auth

- Detector runs server-side as part of auth pipeline. No client-side detection.
- T&S role can read `auth_security_events`. Regular users read only their own (for "your recent logins" page).
- RLS: `auth_security_events.user_id = auth.uid()` self read; `role = 't_and_s'` full read.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Detection latency added to login | <100 ms p99 (cache hit), <600ms (cache miss) |
| Provider quota usage | <80% of free tier daily |
| Cache hit ratio | ≥85% |
| Availability | 99.9% (failover graceful) |
| Privacy | hashed IPs only; raw IP only in transit |

## 6. Dependencies

- VPNAPI free tier (HTTP).
- MaxMind GeoIP2 Anonymous-IP DB (self-host).
- Redis cluster.

## 7. Observability

- Metrics: `flicko_vpn_detect_requests_total{result, provider}`, `flicko_vpn_detect_cache_hit_ratio`, `flicko_vpn_detect_provider_errors_total{provider}`.
- Logs: hashed IP only, never raw.
- Traces: span on each detect call.
- Alerts: provider error rate >5% for 10m → fall back; cache hit < 70% for 1h → investigate.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| VPNAPI down | detection skipped | fallback to MaxMind; if both fail, no warning, log "detection_unavailable" |
| Quota exhausted | provider 429s | switch to MaxMind for the day; reset at UTC midnight |
| Provider returns false positive | user warned unnecessarily | non-accusatory copy; user can dismiss |
| IP hash collision | trivial cache mismatch | SHA-256 with daily salt makes collision cosmologically rare |

## 9. Threat Model

**Attackers**
- A1: Fraudster cycling VPNs to create accounts. Mitigation: this feature *signals* but does not block. T&S correlates with other signals (device fingerprint, behavior).
- A2: Adversary forges X-Forwarded-For headers. Mitigation: trusted proxy list; only Cloudflare-signed `CF-Connecting-IP` accepted.
- A3: Privacy-conscious user wants their IP not stored. Mitigation: hashed at the boundary; `/24` truncation for analytics.
- A4: Subpoena requests "all VPN-using users." Mitigation: legal team has a documented response. Hashes are not directly reversible.

**Assets**
- Hashed IP signal in `auth_security_events`.
- Provider API key (Vault).

**Limitations (documented for users)**
- Detection is best-effort; not all VPNs are flagged.
- Detection does not affect account standing automatically.
