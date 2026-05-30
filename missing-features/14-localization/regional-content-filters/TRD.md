# Regional Content Filters — Technical Requirements

## 1. Architecture Overview

```
                            ┌──────────────┐
                            │  Cloudflare  │
                            │  X-Country   │
                            └──────┬───────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                       Go Backend                             │
│                                                              │
│  middleware.Region                                           │
│       │                                                      │
│       ▼                                                      │
│  ctx.region, ctx.age_attestations                            │
│       │                                                      │
│       ▼                                                      │
│  Read handlers (messages, channels, search)                  │
│       │                                                      │
│       ▼                                                      │
│  filter.Apply(items, region, viewer)                         │
│       │                                                      │
│       ├── load rules (LRU 60s + Redis 5m + DB)               │
│       ├── for each item: match(rule, item)                   │
│       └── replace hidden items with placeholder              │
│       │                                                      │
│       ▼                                                      │
│  audit.Log(region, rule_id, item_id, action)                 │
└─────────────────────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/i18n/regional-content-filters/service.go`
  - `Apply(items []Filterable, viewer Viewer) (filtered []Filterable, hidden []HiddenItem)`
  - `MatchRule(rule Rule, item Filterable) bool`
- **Workers:** `backend/internal/services/i18n/regional-content-filters/sync_worker.go` — pulls fresh rule definitions from admin tool
- **Middleware:** `backend/internal/middleware/region.go` resolves viewer region
- **Handlers:** wraps existing read handlers; admin endpoints for rules CRUD
- **Repo:** `backend/internal/repo/region_rules_repo.go`
- **Audit:** `backend/internal/repo/region_filter_audit_repo.go`

### Mobile (Flutter)
- **Cross-cutting:** `mobile/lib/core/region/`
  - `data/region_repository.dart`
  - `domain/region.dart`, `region_rule_match.dart`
  - `application/region_provider.dart`
  - `presentation/hidden_placeholder_widget.dart`
- **Hooks:** any feature module that lists user-generated items wraps the items in `HiddenAware<T>` to render placeholder when needed

### Infra
- DB: `region_rules`, `region_rule_assignments`, `region_filter_audit` (see SCHEMA)
- Cache: Redis `rules:<region>` TTL 5m; LRU in process TTL 60s
- AI: optional ML classifier `backend/internal/services/i18n/regional-content-filters/classifier/` — phase 2; v1 is regex/hash only
- Queue: NATS subject `flicko.region_filter.audit.*` for async logging
- External: optional partners (Thorn, INHOPE) for hash lists — not v1

## 3. API Contracts

### REST

```
GET    /api/v1/i18n/region                           returns viewer's resolved region + age attestations
PATCH  /api/v1/profile/me { region_code }            user override
POST   /api/v1/profile/me/age-attestation            set age flag (no DOB stored)
GET    /api/v1/admin/region-rules                    list rules (admin only)
POST   /api/v1/admin/region-rules                    create
PATCH  /api/v1/admin/region-rules/:id                update
DELETE /api/v1/admin/region-rules/:id                soft-delete
GET    /api/v1/i18n/hidden-explainer/:audit_id       explainer for a hidden item
POST   /api/v1/i18n/appeal                           submit appeal for a hidden item
```

### Payloads

```jsonc
// Hidden placeholder in response (instead of message body)
{
  "id": "msg_xxx",
  "type": "hidden_placeholder",
  "reason": {
    "rule_id": "de.symbols.nazi",
    "region": "DE",
    "summary": "Hidden in Germany due to local law"
  },
  "audit_id": "audit_yyy"
}

// Rule definition (admin)
{
  "id": "de.symbols.nazi",
  "region_codes": ["DE"],
  "name": "Banned Nazi symbols (StGB §86a)",
  "kind": "regex",
  "pattern": "\\b(swastika|hakenkreuz)\\b",
  "applies_to": ["message_text", "server_name", "channel_name", "bio"],
  "action": "hide",
  "enabled": true,
  "legal_ref": "StGB §86a",
  "version": 1
}

// Age attestation
{ "scope": "kr_19_plus", "confirmed": true }
```

## 4. Permissions & Auth

- Read endpoints: any signed-in user.
- `PATCH /profile/me`: user JWT.
- Admin rules CRUD: requires `regional_filter.admin` scope (Flicko legal team only).
- RLS:
  - Rules table public read for *enabled* rules; private to admins for editing.
  - Audit table per-user read (own only); admin full read.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| filter.Apply p99 latency | <5ms for batch of 50 items |
| Rule cache hit rate | ≥99% |
| Audit write throughput | 5k/sec (async via NATS) |
| Region detection accuracy | ≥98% |
| Regex eval | hard timeout 50ms per pattern |
| Storage growth | ~10kb / 1k filtered items (audit) |
| Availability | 99.99% (degrades to over-block on failure) |

## 6. Dependencies

### Existing
- `multi-language-50` (provides `i18n_locales.region_default`)
- `profile_service` (region_code column)
- Cloudflare/CDN forwarding `X-Country`

### New libraries
- Go: `github.com/oschwald/maxminddb-golang v1.13.0` for fallback IP geo (free MaxMind GeoLite2)
- Go: `regexp` stdlib + RE2 (no catastrophic backtracking)
- Flutter: nothing new

### External
- MaxMind GeoLite2 (free CC-BY-SA license) — country DB, refreshed monthly
- Cloudflare (we already use it)

## 7. Observability

- Metrics:
  - `flicko_region_filter_total{region,rule_id,action}` — counter
  - `flicko_region_filter_latency_seconds` — histogram
  - `flicko_region_filter_cache_hit_total{layer}` — counter
  - `flicko_region_filter_audit_writes_total{status}` — counter
- Logs: WARN on rule timeout; ERROR on rule storage corruption
- Traces: OTel span `region.filter.apply` wrapping the per-item evaluation
- Dashboards: filter rate by region, top fired rules, false-positive trend

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Rule storage unavailable | filtering can't apply | fail closed: hide items with safety-default rules |
| Bad regex | timeout per call | RE2 + 50ms timeout; ignore failed rule |
| Cloudflare header missing | wrong region | fallback IP geo via MaxMind |
| Profile region missing | unknown region | apply only globally-mandatory rules |
| Audit write fails | compliance gap | retry; backup write to local file; alert |
| ML classifier (phase 2) high latency | UX delay | timeout 200ms; fall back to regex-only |

## 9. Implementation Notes

### Rule kinds (v1)
- `regex` — pattern against text content
- `hash` — perceptual hash against media
- `attribute` — match by message metadata (e.g. `is_loot_box: true` for KR)
- `age_gate` — require age attestation

### Filter chain
```go
type Filterable interface { Text() string; Media() []Media; Attributes() map[string]any; ViewerRegion() string }

func Apply(item Filterable, viewer Viewer) (hidden bool, ruleID string) {
    rules := loadRulesForRegion(viewer.Region) // LRU
    for _, r := range rules {
        if !r.Enabled { continue }
        if !r.AppliesTo(item.Type()) { continue }
        switch r.Kind {
        case "regex":
            if matchedRegex(r.Pattern, item.Text()) { return true, r.ID }
        case "hash":
            if matchedHash(r.HashList, item.Media()) { return true, r.ID }
        case "attribute":
            if matchedAttr(r.Attrs, item.Attributes()) { return true, r.ID }
        case "age_gate":
            if !viewer.HasAttestation(r.AgeScope) { return true, r.ID }
        }
    }
    return false, ""
}
```

### Region resolution priority
1. `profile.region_code` (manual)
2. `Cf-IPCountry` header (Cloudflare)
3. `X-Country` (other CDNs)
4. MaxMind lookup on remote IP
5. `XX` (unknown)

### Transparency
- Hidden item placeholder includes `audit_id`; tapping fetches `/hidden-explainer/:audit_id` returning rule + legal_ref.
- Appeal endpoint sends to legal queue; do not auto-restore.

## 10. Testing Strategy

- Unit (Go): match-engine table-driven, 200+ cases per rule kind.
- Property: regex pattern × random input — assert no panics, no >50ms eval.
- Integration: Postgres + Redis test container; assert pg_notify cache invalidation < 1s.
- E2E: KR under-19 simulation; assert age-gate enforced; transparency UI works.
- Compliance: golden corpus with 500 hand-tagged samples per major region; weekly regression run.
- Performance: k6 — 1000 messages/req with 30 rules active; p99 < 50ms.
- Adversarial: try unicode tricks (zero-width chars, RTL override, look-alikes) — ensure normalized matching.
