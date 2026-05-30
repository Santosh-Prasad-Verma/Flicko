# Multi-Currency — Technical Requirements

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                         Daily Cron (GH Action)                     │
│                                                                    │
│  04:00 UTC ─▶ OXR /latest.json ─▶ POST /api/v1/internal/fx/sync    │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│                          Go Backend                                │
│                                                                    │
│  fx_sync_worker ──▶ currency_rates table                           │
│                                                                    │
│  HTTP ──▶ middleware.Currency ──▶ ctx.displayCcy                   │
│                       │                                            │
│                       ▼                                            │
│           pricing_service.GetSku(sku_id, displayCcy)               │
│                       │                                            │
│           ┌───────────┴────────────┐                               │
│           ▼                        ▼                               │
│   currency_rates             format_money(locale, usd_cents, ccy)  │
│   (LRU cache 5m)             (intl.NumberFormat equivalent)        │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼  GET /api/v1/boosts/skus
┌────────────────────────────────────────────────────────────────────┐
│                          Mobile (Flutter)                          │
│                                                                    │
│  CurrencyProvider (Riverpod) ──▶ MoneyFormat utility               │
│                                                                    │
│  LocalizedPrice widget ──▶ shows display + (optional) USD tooltip  │
└────────────────────────────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/i18n/multi-currency/service.go`
  - `GetRate(ctx, ccy) (rate float64, fetchedAt time.Time, err error)`
  - `FormatMoney(locale, usdCents int64, displayCcy string) (string, error)`
  - `Convert(usdCents int64, ccy string) (displayUnits int64, err error)`
- **Worker:** `backend/internal/services/i18n/multi-currency/sync_worker.go` — daily fetch
- **Middleware:** `backend/internal/middleware/currency.go` — resolves user's display ccy from header / profile
- **Handlers:** every pricing handler accepts `?display_ccy=` query and includes display in response
- **Repo layer:** `backend/internal/repo/currency_rates_repo.go`

### Mobile (Flutter)
- **Cross-cutting folder:** `mobile/lib/core/currency/`
  - `data/`: `currency_repository.dart` (calls `/api/v1/i18n/currencies`)
  - `domain/`: `currency.dart`, `money.dart` value objects
  - `application/`: `currency_provider.dart` Riverpod
  - `presentation/`: `localized_price.dart` widget
- **Hooked into:** boosts/, premium/, marketplace/, gifts/ feature modules

### Infra
- DB: `currency_rates`, `currencies` tables (see SCHEMA)
- Cache: Redis `fx:rate:<ccy>` TTL 25h (slightly more than refresh window so cron miss doesn't blank cache)
- AI: not used
- Queue: not used (single daily cron)
- External: Open Exchange Rates (primary), Frankfurter.app (fallback)

## 3. API Contracts

### REST

```
GET    /api/v1/i18n/currencies                          list supported display ccys
GET    /api/v1/i18n/fx/rates                            full rate table (cached, public)
GET    /api/v1/i18n/fx/convert?from=USD&to=INR&amount=499   one-shot convert
PATCH  /api/v1/profile/me { preferred_currency }        user override
POST   /api/v1/internal/fx/sync                         worker-only daily upsert
```

### Public payload examples

```jsonc
// GET /api/v1/i18n/currencies
{
  "currencies": [
    { "code": "USD", "symbol": "$",  "english_name": "US Dollar",       "native_name": "US Dollar",       "decimals": 2, "fmt": "${amount}" },
    { "code": "INR", "symbol": "₹",  "english_name": "Indian Rupee",    "native_name": "भारतीय रुपया",    "decimals": 2, "fmt": "₹{amount}" },
    { "code": "JPY", "symbol": "¥",  "english_name": "Japanese Yen",    "native_name": "円",              "decimals": 0, "fmt": "¥{amount}" },
    { "code": "KWD", "symbol": "د.ك","english_name": "Kuwaiti Dinar",   "native_name": "دينار كويتي",      "decimals": 3, "fmt": "{amount} د.ك" }
  ]
}

// GET /api/v1/i18n/fx/rates  (USD base)
{
  "base": "USD",
  "fetched_at": "2026-05-29T04:00:01Z",
  "stale": false,
  "rates": { "EUR": 0.92, "INR": 83.42, "JPY": 154.10, "BRL": 5.07, "KRW": 1378.0, /* ... */ }
}

// Boost SKU response (existing endpoint, augmented)
{
  "id": "boost-tier-1",
  "amount_usd_cents": 499,
  "display": {
    "currency": "INR",
    "amount": 41700,        // smallest unit (paise)
    "formatted": "₹417",
    "rate": 83.42,
    "rate_fetched_at": "2026-05-29T04:00:01Z",
    "stale_hours": 0
  }
}
```

## 4. Permissions & Auth

- `/i18n/currencies` and `/i18n/fx/rates` are public (no auth).
- `/i18n/fx/convert` public, rate-limited 60/min/IP.
- `PATCH /profile/me` requires user JWT.
- `/internal/fx/sync` requires service-role JWT (worker only).

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| `format_money` p99 latency | <1 ms |
| `/fx/rates` p99 latency | <50 ms (cached) |
| FX freshness | <26h (alert at 30h) |
| Cache hit rate (Redis) | ≥99% |
| Throughput | 10k rps on `/fx/rates` |
| Availability | 99.95% (degraded mode = stale rates) |
| Storage cost | <$0.001/user/mo |
| Compute cost | $0 (no per-call AI) |

## 6. Dependencies

### Existing
- `multi-language-50` (locale codes drive number formatting)
- `profile_service` (preferred_currency column)
- `pricing_service` (existing, reads SKUs in USD)
- `mail-gateway` (receipts)

### New libraries
- Go: `github.com/Rhymond/go-money v1.0.10` for safe currency arithmetic
- Go: `golang.org/x/text/currency v0.16.0` for ISO code validation
- Flutter: `intl: ^0.19.0` (already pinned)
- No NPM/external service SDKs

### External
- Open Exchange Rates Free plan: 1,000 calls/mo (we use ~30)
- Frankfurter.app: unlimited free, ECB-backed (fallback)
- Stripe SDK (existing)

## 7. Observability

- Metrics:
  - `flicko_fx_sync_total{status,source}` — counter
  - `flicko_fx_age_hours` — gauge (most-recent fetch age)
  - `flicko_fx_lookup_total{ccy,hit_layer}` — counter
  - `flicko_money_format_errors_total{ccy}` — counter
- Logs: structured JSON; WARN on stale > 25h; ERROR on sync 3rd-fail
- Traces: OTel span on `format_money` + `Convert`
- Dashboards: panel on i18n Grafana board: rate freshness, top-10 displayed ccys, conversion errors

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| OXR API down | sync skipped | retry; fallback to Frankfurter; eventually serve stale with banner |
| Both providers down | rates stale | last-good rates served; alert PagerDuty |
| Bad rate value (negative, NaN) | broken display | sanity check rate ∈ (0, 1e6); reject and keep prior |
| User-picked ccy disabled | broken display | revert to region default with toast |
| Unicode formatting bug | mis-render | golden tests for top-20 ccys × top-10 locales |
| Display drift > 5% from charge | trust loss | always show "(charged in USD)" footnote |

## 9. Implementation Notes

### `format_money` rules
- Inputs: `locale` (BCP-47), `usdCents` (int64), `displayCcy` (ISO 4217)
- Rate from cache; if stale > 30h, throw `ErrFxStale` and let caller decide
- Convert to displayCcy smallest unit, then to display unit per ccy decimals
- Round half-up
- Format using `golang.org/x/text/message`'s `Printer.Sprintf("%v", currency.Amount)` — this is locale-aware

```go
func FormatMoney(locale string, usdCents int64, ccy string) (string, error) {
    rate, _, err := svc.GetRate(ctx, ccy)
    if err != nil { return "", err }
    decimals := currencyDecimals[ccy] // 0, 2, or 3
    units := float64(usdCents) / 100.0 * rate
    rounded := math.Round(units*math.Pow10(decimals)) / math.Pow10(decimals)
    p := message.NewPrinter(language.MustParse(locale))
    return p.Sprintf("%v", currency.MustParseISO(ccy).Amount(rounded))
}
```

### Mobile equivalent
```dart
String formatMoney(Locale locale, int usdCents, String ccy) {
  final rate = ref.read(fxRatesProvider).valueOrNull?[ccy] ?? 1.0;
  final decimals = currencyDecimals[ccy] ?? 2;
  final units = (usdCents / 100.0) * rate;
  final rounded = (units * pow(10, decimals)).round() / pow(10, decimals);
  return NumberFormat.currency(
    locale: locale.toString(),
    name: ccy,
    decimalDigits: decimals,
  ).format(rounded);
}
```

## 10. Testing Strategy

- Unit tests for `Convert`, `FormatMoney`: table-driven covering 50 ccys × 10 amounts × 5 locales (small subset golden).
- Property test: `Convert(usd, ccy) → display`; `Convert(display.toUsd(ccy)) ≈ usd ± 1 cent`.
- Snapshot tests for rendered widget across top 20 currencies.
- Integration: spin Postgres + cron worker; assert daily upsert with mocked OXR HTTP server.
- Failure-injection: kill OXR mock; assert fallback to Frankfurter.
- E2E (Maestro): set device locale ja-JP, view Premium screen, assert `¥740`-style display.
