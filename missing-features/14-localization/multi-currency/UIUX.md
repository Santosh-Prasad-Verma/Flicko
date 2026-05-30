# Multi-Currency — UI/UX Design

## 1. Design Principles

- **Trust through transparency:** always show the actual charged amount in fine print near the local-currency display.
- **No surprise rates:** if FX is stale > 24h, surface a small note; never hide it.
- **Local primary, USD secondary:** in v3, local is the headline; USD is the safety net.
- **Round generously, never deceptively:** round half-up to currency-appropriate precision.
- **Symbol + ISO when ambiguous:** `$` is overloaded (USD, AUD, CAD, etc.); we show `US$ 4.99`, `A$ 7.20` to disambiguate when locale doesn't already imply it.

## 2. Information Architecture

Where this lives:
- Entry point: `Settings → Language & Region → Currency` (primary)
- Implicit on every pricing surface (Boosts, Premium, Marketplace, Gifts, Receipts)
- Deep link: `flicko://settings/currency`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | CurrencySettingsScreen | pick display currency | content, search, applied, error |
| 2 | LocalizedPrice (component) | render a price | normal, stale-warning, free, refunded |
| 3 | ReceiptScreen | post-purchase confirmation | local + USD lines |
| 4 | StaleFXBanner | site-wide warning when rates older than 30h | visible, dismissed |

## 4. Wireframes (ASCII)

### Screen 1 — CurrencySettingsScreen

```
┌────────────────────────────────────────┐
│ ← Currency                             │
├────────────────────────────────────────┤
│  Search                                │
│ ┌────────────────────────────────────┐ │
│ │ 🔍  Search currencies              │ │
│ └────────────────────────────────────┘ │
│                                        │
│  Suggested                             │
│ ┌────────────────────────────────────┐ │
│ │ ₹  Indian Rupee     INR  (region)  │ │
│ │ $  US Dollar        USD  (default) │ │
│ └────────────────────────────────────┘ │
│                                        │
│  All currencies                        │
│ ┌────────────────────────────────────┐ │
│ │ €  Euro             EUR            │ │
│ │ ¥  Japanese Yen     JPY            │ │
│ │ £  British Pound    GBP            │ │
│ │ R$ Brazilian Real   BRL            │ │
│ │ ...                                │ │
│ └────────────────────────────────────┘ │
│                                        │
│  Rates updated 4 hours ago             │
└────────────────────────────────────────┘
```

### Screen 2 — Boost SKU card (with localized price)

```
┌────────────────────────────────────────┐
│ Server Boost — Tier 1                  │
│                                        │
│   ₹417 / month                         │
│   $4.99 USD billed monthly             │
│                                        │
│  [   Subscribe   ]                     │
│                                        │
│  Charged in USD. Your bank may apply   │
│  its own conversion rate.              │
└────────────────────────────────────────┘
```

### Screen 3 — Receipt email (HTML excerpt)

```
You paid:           $4.99 USD
Approximate:        ₹417 INR (rate 83.42)
Date:               2026-05-29
Reference:          ch_3PXyz...

Need help? Reply to this email.
```

### Screen 4 — Stale FX banner

```
┌──────────────────────────────────────────┐
│ ⓘ  Exchange rates are 2 days old.        │
│ We'll show approximate prices until the  │
│ next refresh.                            │
└──────────────────────────────────────────┘
```

## 5. Component Specs

### `LocalizedPrice` widget
- Props: `int usdCents`, `String? overrideCcy`, `bool showUsdSecondary = true`, `bool compact = false`
- Reads `CurrencyProvider.currency` and `FxRatesProvider`
- Behavior:
  - If user ccy == USD: render `$4.99` only (no secondary)
  - Else: render `<symbol><amount>` primary, `$X.XX USD` secondary in 0.85em muted
  - If `compact=true`: drop secondary
  - If FX stale > 30h: small clock icon next to the price + tooltip explaining
- Tokens: `textTheme.titleLarge` for primary, `textTheme.bodySmall.color = onSurfaceVariant` for secondary
- Always renders inside a `BidiText` so RTL locales handle correctly

### `CurrencyTile`
- Props: `Currency ccy`, `bool selected`, `String? badge`
- Shows: `[symbol] [native_name (English_name)] [ISO code] [optional badge: Suggested]`
- 56pt tap target

### `StaleFXBanner`
- Inline at the top of any pricing screen when `fxAgeHours > 30`
- Auto-hides on refresh
- Dismissable per-session

## 6. Empty / Error / Loading

- **No FX yet (cold start):** show USD-only with banner "Local pricing coming soon".
- **Error fetching rates:** keep last-good rates; banner with retry.
- **Loading:** skeleton on price (shimmer-bar 80×24).

## 7. Copy

| Surface | Copy (en source) |
|---------|------------------|
| Settings title | Currency |
| Settings hint | Choose how prices are shown across Flicko. |
| Stale banner | Exchange rates are {n} {unit} old. We'll show approximate prices until the next refresh. |
| Charged-in-USD footnote | Charged in USD. Your bank may apply its own conversion rate. |
| Free | Free |
| Tooltip on stale icon | Rate from {date}. Latest: {time-since}. |
| Search placeholder | Search currencies |
| Section: Suggested | Suggested |
| Section: All | All currencies |
| Receipt local-amount line | Approximate {symbol}{amount} {ccy} (rate {rate}) |

Voice: friendly, concise, second-person.

## 8. Motion

- Currency change: `LocalizedPrice` widgets crossfade 200ms when ccy changes.
- Banner: slide-down on appear, fade-out on dismiss.
- Reduced-motion: instant.

## 9. Accessibility

- Each `LocalizedPrice` exposes a Semantics label combining primary + secondary so screen readers say "₹417 — equivalent to four dollars ninety-nine cents US".
- Stale icon has Semantics `Label("Rate is {n} hours old, may be approximate.")`.
- Color contrast ≥4.5:1; secondary text passes contrast tests in dark mode.
- Tab order: ccy picker → search → list → footer.

## 10. Responsive

- Phone: full-screen list.
- Tablet: master-detail (list left, sample prices preview right).
- Web: identical to tablet.

## 11. Theming

- Light, Dark, AMOLED — default tokens.
- Primary price uses `colorScheme.onSurface`; secondary uses `colorScheme.onSurfaceVariant`.
- Stale icon tint matches `colorScheme.tertiary`.

## 12. Edge-case Rendering Rules

- **Discount strike-through:** `<s>$5.99</s> $4.99` → `<s>₹500</s> ₹417`. Same currency on both, no mixed.
- **Per-period prices:** `₹417 / month` not `₹417 / mo` (locale-aware abbreviation).
- **Tax-inclusive marker (where required):** "incl. VAT" appended for EU, "incl. GST" for IN/AU. Outside scope of v1 but copy reserved.
- **Currency disambiguation:** when ccy is `$`-family but locale doesn't make it obvious, prefix with country code: `US$`, `A$`, `CA$`.

## 13. A/B Test Plan

- Variant A (control): USD-only prices.
- Variant B: dual display ($4.99 USD ~ ₹417).
- Variant C: local primary, USD footnote (₹417 / charged in USD).
- Split: non-US users 1/3 each.
- Primary metric: checkout completion rate.
- Decision: pick the highest-converting variant; fall back to B if conversion ties.
