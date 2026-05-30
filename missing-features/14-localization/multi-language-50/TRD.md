# Multi-Language 50+ — Technical Requirements

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                            Mobile (Flutter)                             │
│  ┌──────────────────┐   ┌────────────────┐   ┌───────────────────────┐ │
│  │ LocaleResolver   │──▶│ LocaleProvider │──▶│ MaterialApp.locale    │ │
│  │ (profile→device) │   │ (Riverpod)     │   │ → AppLocalizations.of │ │
│  └──────────────────┘   └────────────────┘   └───────────────────────┘ │
│            │                                            │              │
│            ▼                                            ▼              │
│  ┌──────────────────┐                       ┌──────────────────────┐   │
│  │ ARB files (50)   │                       │ format() helpers     │   │
│  │ app_<lang>.arb   │                       │ ICU plurals + gender │   │
│  └──────────────────┘                       └──────────────────────┘   │
└──────────────────────────────────────┬─────────────────────────────────┘
                                       │ HTTP /api/v1/* + Accept-Language
                                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│                            Go Backend                                   │
│  ┌─────────────────┐   ┌─────────────────┐   ┌───────────────────────┐ │
│  │ LocaleMiddleware│──▶│ ctx.lang        │──▶│ i18n.Lookup(code,lang)│ │
│  └─────────────────┘   └─────────────────┘   └───────────┬───────────┘ │
│                                                          │             │
│  ┌──────────────────────────────────────┐                │             │
│  │  AI handlers (Aura, summarize, etc.) │◀───target_lang─┘             │
│  │  Push builder, mail-gateway          │                              │
│  └──────────────────────────────────────┘                              │
└──────────────────────────────────────┬─────────────────────────────────┘
                                       │
                ┌──────────────────────┼──────────────────────┐
                ▼                      ▼                      ▼
        ┌───────────────┐     ┌────────────────┐    ┌────────────────┐
        │ Postgres      │     │ Redis LRU      │    │ Crowdin OSS    │
        │ i18n_messages │     │ i18n:msg:..    │    │ (translations) │
        │ i18n_locales  │     └────────────────┘    └────────┬───────┘
        └───────────────┘                                    │
                                                             │ nightly
                                                             ▼
                                                    GitHub Action PR
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/i18n/multi-language-50/service.go`
  - Public API: `Lookup(ctx, code, lang) (string, error)`, `LookupOrDefault(ctx, code, lang, args ...any) string`
  - Implementation: in-memory LRU (4096 entries) → Redis → Postgres → fallback to en
- **Cache:** `backend/internal/services/i18n/multi-language-50/cache.go` — LRU + invalidation listener on `pg_notify`
- **Middleware:** `backend/internal/middleware/locale.go` — resolves user locale per request
- **Handlers:** all error responses pass through `handlers/error_response.go`
- **Repo layer:** `backend/internal/repo/i18n_repo.go`
- **Workers:** `backend/internal/services/i18n/multi-language-50/sync_worker.go` — nightly Crowdin pull

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/core/i18n/` (cross-cutting, not a feature folder)
  - `data/`: `locale_repository.dart` — reads/writes profile.preferred_lang
  - `domain/`: `locale.dart` entity, `resolve_locale.dart` usecase
  - `application/`: `locale_provider.dart` (Riverpod StateNotifier)
  - `presentation/`: handled by `mobile/lib/features/settings/presentation/language_settings_screen.dart`

### Infra
- DB: Supabase Postgres tables `i18n_messages`, `i18n_locales`, `i18n_translation_credits`
- Realtime: Postgres `pg_notify('i18n_messages_changed')` → backend LRU bust
- Cache: Redis keys `i18n:msg:<code>:<lang>` (TTL 10m), `i18n:locales:enabled` (TTL 5m)
- Storage: Appwrite bucket `i18n-screenshots` (Crowdin-uploaded contexts)
- Search: not used
- AI: Groq for translation drafts; DeepL Free for translator-facing MT suggestions
- Queue: not needed — sync is a single nightly cron job

## 3. API Contracts

### REST

```
GET    /api/v1/i18n/locales                         list enabled locales
GET    /api/v1/i18n/messages?lang=<code>            bulk fetch (used at app boot)
GET    /api/v1/i18n/messages/:code?lang=<code>      single (rare)
PATCH  /api/v1/profile/me { preferred_lang }        update user preference
POST   /api/v1/i18n/admin/messages                  upsert (admin only)
POST   /api/v1/i18n/admin/sync-crowdin              manual trigger
```

### WebSocket / Centrifugo
- Not required. Locale changes are user-scoped and don't need broadcast.
- Optional: `i18n:admin` channel emits `i18n.message.updated` events for translation team dashboards.

### Payloads

```jsonc
// GET /api/v1/i18n/locales
{
  "locales": [
    { "code": "en",    "native_name": "English",        "rtl": false, "flag": "🇺🇸", "coverage_pct": 100 },
    { "code": "pt-br", "native_name": "Português (BR)", "rtl": false, "flag": "🇧🇷", "coverage_pct": 98.4 },
    { "code": "ar",    "native_name": "العربية",         "rtl": true,  "flag": "🇸🇦", "coverage_pct": 87.1 }
  ]
}

// GET /api/v1/i18n/messages?lang=ja  (bulk)
{
  "lang": "ja",
  "fallback_lang": "en",
  "messages": {
    "err.not_found": "見つかりません。",
    "notif.mention.title": "{actor}さんがあなたをメンションしました"
  },
  "missing_keys_fell_back_to_en": ["err.exotic_edge_case"]
}

// PATCH /api/v1/profile/me
{ "preferred_lang": "pt-br" }

// AI handler request — every AI endpoint adds:
{ "..." : "...", "target_lang": "ja" }
```

## 4. Permissions & Auth

- Reading messages and locales is public — no auth.
- `PATCH /profile/me` requires user JWT.
- Admin endpoints require `admin_users` membership (RLS plus middleware check).
- Required scopes: `i18n.admin.write` for upsert / sync.
- RLS policies: see `SCHEMA.md` §2.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| `i18n.Lookup` p50 latency | <0.2 ms (LRU hit) |
| `i18n.Lookup` p99 latency | <5 ms (Redis hit) |
| `i18n.Lookup` p99 latency cold | <50 ms (Postgres) |
| Bulk messages bundle response | <200 ms p95 |
| Cache hit rate | ≥98% steady state |
| App bundle size delta | <2 MB (deferred-load ARBs) |
| Crowdin sync wallclock | <5 min for full pull |
| Throughput | 5k req/s sustained on bulk endpoint |
| Availability | 99.9% — degraded mode falls back to en |
| Storage cost | <$0.001 per user/month |
| Compute cost | <$0.0001 per call |
| GDPR | EU users' preferred_lang in EU shard |

## 6. Dependencies

### Existing services
- `auth_service` (for profile lookup)
- `profile_service` (PATCH preferred_lang)
- `mail-gateway` (template selection)
- `notification_service` (push localization)
- `aura_service`, `summarizer_service`, `transcript_service` (target_lang plumbing)

### New libraries
- Go: `github.com/nicksnyder/go-i18n/v2 v2.4.0` for ICU MessageFormat
- Go: `golang.org/x/text/language v0.16.0` for BCP-47 parsing/matching
- Flutter: `intl: ^0.19.0` (already pinned)
- Flutter: `flutter_localizations` (built in)
- Dart dev: custom analyzer plugin in `tools/lints/no_hardcoded_strings/`

### External APIs
- Crowdin REST API v2 (OSS plan): 5000 req/h
- DeepL Free MT: 500k chars/mo
- Groq for AI prompt locale routing: existing quota

## 7. Observability

- Metrics:
  - `flicko_i18n_lookup_total{lang,hit_layer}` — counter (lru/redis/db/fallback)
  - `flicko_i18n_fallback_total{from,to}` — counter
  - `flicko_i18n_bulk_bundle_bytes` — histogram
  - `flicko_i18n_locale_dau{code}` — gauge
- Logs: structured JSON; `INFO` on lookups, `WARN` on fallback to en, `ERROR` on Postgres unreachable
- Traces: OTel span `i18n.Lookup` wrapping cache → db chain
- Dashboards: Grafana `i18n` board — lookup hit rate, fallback rate, per-locale DAU, Crowdin coverage chart

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Postgres unreachable | new locales can't load | LRU + Redis still serve; admin alert; fall back to en for cold lookups |
| Redis down | DB hit rate spikes | LRU still warm; auto-scale DB read replicas |
| Crowdin API throttled | nightly sync delayed | retry with exponential backoff; alert on 3 consecutive misses |
| ARB load fails on mobile | UI is blank | static fallback to in-bundle `app_en.arb`; Sentry breadcrumb |
| Translator vandalism | offensive copy ships | reviewed=false flag blocks ship; CI enforces reviewed=true for prod releases |
| Locale code typo by user | preference rejected | server validates against `i18n_locales` table |
| pg_notify channel saturated | LRU stale | TTL forces refresh in 60s anyway |

## 9. Security Considerations

- **Input validation:** locale codes constrained to `^[a-z]{2,3}(-[a-z0-9]{2,4})?$`; reject otherwise.
- **Header parsing:** `Accept-Language` parsed by `golang.org/x/text/language.Parse` only — never raw-string concat.
- **Translator XSS:** Crowdin allows arbitrary text; on import we sanitize for HTML in mail templates with `template.HTMLEscapeString`. ARBs in mobile are rendered as `Text` widgets (no HTML eval).
- **Rate limit:** bulk endpoint capped at 60 req/min per IP — no reason to fetch 100× a minute.
- **Audit:** every admin upsert logged with `actor_id`, `code`, `lang`, `before/after_text` (in `audit_log`).

## 10. Testing Strategy

- Table-driven Go tests for `Lookup` with hit-miss matrix.
- Fuzz test on locale parser (`go-fuzz` corpus 5k codes).
- Flutter widget golden tests per launch locale × critical screen.
- Pseudo-locale layout test: every screen must render without RenderFlex overflow at xq-XQ.
- Integration: spin up Postgres + Redis testcontainer; assert pg_notify → LRU bust within 1s.
- E2E (Maestro): set device locale to ja-JP; verify onboarding, push, AI reply all in Japanese.
- Chaos: kill Postgres mid-bulk; assert Redis-only path returns 200 with degraded flag.
