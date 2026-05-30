# Multi-Currency — Product Requirements

> **One-line:** Show economy values in the user's local currency with daily-refreshed FX rates.
> **Status:** Missing — to build
> **Category:** 14-localization
> **Effort:** M
> **Priority:** P1
> **Slug:** `multi-currency`

## 1. Problem

Flicko's economy features (server boosts, premium subscriptions, gift cards, marketplace listings) currently display all prices in USD. A Brazilian user sees `$4.99` and has to mentally convert; a Japanese user sees a price too small to feel meaningful (¥740 ≠ $4.99 mentally).

Real evidence:
- 11 GitHub issues asking "show prices in INR / BRL / EUR".
- Stripe checkout for non-US cards has a 14% higher abandonment rate than US cards (Stripe analytics) — a chunk of which is "I don't trust this price".
- A/B test on similar SaaS shows 8-12% conversion lift when local currency is shown.

Notably, *virtual* currency (Flicko Coins, server XP) must remain unaffected — those are abstract and not pegged to fiat. Only fiat-denominated values (Boosts, Premium, gift card top-ups, marketplace listings) get localized.

## 2. Users & Use Cases

- **Primary persona:** "Riya in Mumbai" — sees Premium priced in INR, decides whether ₹399/mo is worth it.
- **Secondary personas:** server admins running boosts; gift-givers tipping creators; marketplace sellers picking pricing.
- **Top jobs-to-be-done:**
  1. As a non-US user, I want every $ price translated to my currency, so that I can decide quickly.
  2. As a server admin, I want to set a single base price (USD) and let Flicko handle local display, so that I don't manage 50 price lists.
  3. As an analytics user, I want revenue dashboards in USD and per-locale currency, so that finance can reconcile.

## 3. Goals & Non-Goals

**Goals**
- Display all fiat amounts in the user's preferred currency (auto-detected from region, override-able).
- Daily FX refresh from Open Exchange Rates free tier (1,000 calls/mo — we use 1/day = 30/mo).
- 50 supported display currencies (USD, EUR, GBP, JPY, INR, BRL, CNY, KRW, etc.).
- Charging happens in a small set of *settlement currencies* (USD, EUR, GBP, JPY) — display-only conversion for others.
- Format using `intl` `NumberFormat.currency(locale, name)` with native currency glyphs.
- Never store prices in non-USD; only display-converted at request time.

**Non-Goals (out of scope for v1)**
- Charging in 50 currencies (Stripe support varies; we settle in 4).
- Tax calculation (separate feature, requires per-jurisdiction VAT/GST logic).
- Historical FX charts.
- Crypto pricing.
- Affecting virtual currency (Coins, XP, gems) — those are abstract.

## 4. Scope (v1)

- [ ] `currency_rates` table refreshed daily via cron worker
- [ ] `format_money(locale, amount_usd_cents, display_ccy) → string` Go helper
- [ ] Mobile equivalent `MoneyFormat.format(...)` using cached rates
- [ ] User preference `profiles.preferred_currency` (defaults from region)
- [ ] `region → currency` mapping (e.g. IN → INR, BR → BRL)
- [ ] UI override in Settings → Language & Region
- [ ] All price components migrated to `LocalizedPrice` widget
- [ ] Stripe checkout still settles in USD/EUR/GBP/JPY (no settlement-currency change)
- [ ] FX-rate-fetched-at indicator in fine print
- [ ] Round-half-up to currency-appropriate precision (JPY=0 decimals; KWD=3)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Non-USD displays | 60% of price views by non-US users | PostHog event |
| Conversion lift | +8% non-US checkout success | A/B test |
| FX freshness | <24h stale | DB `currency_rates.fetched_at` |
| FX failures | <1/month | sync worker logs |
| Cost | $0 | OXR free tier |

## 6. Open Questions / Risks

- OXR free tier is 1k calls/mo — we use only 30 (one daily fetch). Buffer is huge.
- FX volatility for fiat is small; daily refresh OK. For currencies with capital controls (e.g. ARS), the *official* rate diverges from the *real* rate. Mitigation: show "~" prefix and disclaimer.
- Price psychology: ¥740 looks small, $4.99 looks "premium"; do we adjust *base* price per market? v1 = no, just display. v2 (post-launch) = consider purchasing power parity tiering.
- Refunds: we charge USD, refund USD; user might see slightly different rate than at purchase. Disclose in fine print.
- Round-trip mismatch: a user displays INR, Stripe charges USD; bank converts back. We are transparent: "Charged $4.99 USD (~₹417). Your bank may apply its own rate."

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord Nitro | USD only globally | We localize display |
| Patreon | Tier in USD, settlement local | Closer to our v2 vision |
| Steam | Region-priced (PPP-adjusted) | Aspirational v3 |
| Spotify | Per-region pricing | Aspirational v3 |
| Substack | USD-only | We exceed |

## 8. Rollout

- Phase 1: read-only — all prices show converted alongside USD ("$4.99 USD ~ ₹417 INR").
- Phase 2: primary display in local currency, USD in tooltip.
- Phase 3: GA — local currency primary, "(charged in USD)" footnote.
- Kill switch: `feature.multi_currency.enabled` (default ON post-GA); reverts to USD-only.

## 9. Partner / Vendor Notes

- **Open Exchange Rates** Free plan: 1,000 calls/mo, USD base, 170+ currencies. Sign-up via OSS plan if granted; otherwise free hobby plan (1k calls/mo is plenty for one daily fetch).
- **Frankfurter.app** as fallback (free, ECB-backed, no key required).
- **Stripe** charges in USD/EUR/GBP/JPY; we don't change settlement.

## 10. Translator / Locale Notes

- Currency name strings ("US Dollar", "Indian Rupee") are translated via the regular Crowdin pipeline.
- Symbol glyphs come from Unicode CLDR (built into `intl`).
- Decimal/thousand separators come from locale, not currency: ja-JP shows `¥1,000`, de-DE shows `1.000 ¥`, fr-FR shows `1 000 ¥`.
- Right-to-left currency display: Arabic locales show `١٬٠٠٠ $` (currency on the right or per CLDR rule); we trust `intl` to do this correctly.
