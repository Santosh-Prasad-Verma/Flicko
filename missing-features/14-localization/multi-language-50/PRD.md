# Multi-Language 50+ — Product Requirements

> **One-line:** Translate Flicko's UI into 50+ languages via community-driven Crowdin/Weblate workflow.
> **Status:** Missing — to build
> **Category:** 14-localization
> **Effort:** L
> **Priority:** P0
> **Slug:** `multi-language-50`

## 1. Problem

Flicko currently ships English-only. Discord supports 31 languages, Slack 11, Telegram 70+. Roughly 75% of the world's internet users do not have English as their primary language; 60% of users abandon a product within minutes if it is not available in their native tongue (CSA Research, 2020). For an OSS-leaning Discord alternative aiming at a global community, English-only is a hard ceiling on growth.

Real evidence:
- 14 GitHub issues filed against the existing v0.x repo asking "any plans for [es | de | fr | ja | ru | ko | zh-CN | pt-BR | hi | id]?".
- Top-3 referrer countries (Plausible) are India, Brazil, Indonesia — all heavily non-English-first.
- Crash analytics show a 38% lower retention curve for users whose device locale is not `en-*`.

We need a *zero-budget* path to 50+ supported locales that volunteer translators can self-serve, plus a per-user override so a French user on a Polish phone still gets French.

## 2. Users & Use Cases

- **Primary persona:** "Camila in São Paulo" — Portuguese-first college student, joins a study server, expects every button, error, push notification, and AI summary in pt-BR.
- **Secondary personas:** community translators ("Yuki in Osaka", wants to contribute ja-JP without a PR); server admins shipping copy that auto-translates for non-en members; AI-assistant users who want responses in their language.
- **Top jobs-to-be-done:**
  1. As a non-English user, I want the entire app (UI, errors, emails, push) in my language, so that I can actually use Flicko.
  2. As a volunteer translator, I want a web UI to translate strings without cloning the repo, so that I can help in 10 minutes a week.
  3. As an AI feature user, I want AI replies in my locale, so that summaries, transcripts, and Aura answers feel native.

## 3. Goals & Non-Goals

**Goals**
- Ship 50+ locale ARB files in `mobile/lib/l10n/` covering 100% of user-facing strings.
- Backend errors, system events, and AI prompts honor a per-request `target_lang` field.
- A `/translate` workflow (Crowdin OSS plan, free) where volunteers see screenshots + glossary.
- Per-user language override stored in `profiles.preferred_lang`; falls back to device locale, then `en`.
- Pseudo-locale `xq-XQ` (extended-question, expansion +30%) wired in for layout-stress testing.
- CI guards: every new ARB key MUST exist in `app_en.arb` before merge.

**Non-Goals (out of scope for v1)**
- Machine translation as final output (we only use it as a *first draft* for translators).
- Translation of user-generated content (UGC) — that is a separate feature [`auto-translate-messages`].
- Right-to-left mirroring — covered by sibling feature `rtl-support`.
- Locale-specific number/currency formatting beyond what `intl` ships — covered by `multi-currency`.
- Voice/TTS localization (different LiveKit voices per language).

## 4. Scope (v1)

- [ ] 50 launch locales: en, es, pt-BR, fr, de, it, nl, pl, ru, uk, tr, ar, he, fa, ur, hi, bn, ta, te, mr, gu, kn, ml, pa, id, ms, vi, th, tl, zh-CN, zh-TW, ja, ko, sw, am, yo, ig, ha, az, kk, uz, ka, hy, sq, sr, hr, bg, ro, el, fi, cs, sk, hu, da, sv, nb, et, lv, lt, sl
- [ ] ARB extraction tooling (`flutter gen-l10n` already set up)
- [ ] Crowdin project linked, glossary uploaded, screenshots auto-synced
- [ ] Weblate self-hosted as fallback for users who refuse SaaS
- [ ] Backend `i18n.Lookup(code, lang) string` resolver for error codes
- [ ] AI services (Aura, summarizer, transcript) accept `target_lang` and pass to LLM
- [ ] `LocaleProvider` (Riverpod) + in-app picker in Settings
- [ ] `xq-XQ` pseudo-locale auto-generated in dev builds
- [ ] CI: missing-keys check, fuzzy-translation flag, lint for hardcoded strings

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Locale coverage at GA | 50+ locales ≥90% strings | Crowdin progress API |
| Non-English DAU share | 35% within 90d | PostHog `locale` property |
| Translator contributors | 100+ within 90d | Crowdin contributor count |
| AI replies in correct lang | 95% match `target_lang` | sampling eval |
| Bug reports tagged `i18n` | <5/week post-GA | GitHub issues |
| Vendor budget | $0 | invoices |

## 6. Open Questions / Risks

- Will Crowdin approve our OSS plan application? Mitigation: pre-fill Weblate self-hosted as primary, treat Crowdin as upgrade.
- Plurals across Slavic languages (6 forms) — risk of incorrect plural rules. Use ICU MessageFormat strictly.
- AI LLM quality varies by language; we may need per-language eval suites.
- Some legal copy (TOS, privacy) requires *certified* translation — out of scope, English-only with a banner.
- 50 ARB files multiply app bundle size by ~12MB. Mitigation: deferred-load locale ARBs at runtime via `loadString`.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | 31 locales, paid translators, gated | We open it to community, 50+ |
| Slack | 11 locales, enterprise-only depth | We localize free tier fully |
| Telegram | 70+, community-driven (Telegram Translations Platform) | We mirror their model in Crowdin |
| Matrix/Element | ~40 locales via Weblate | We add screenshots + glossary, lower contributor friction |
| Revolt | ~20 locales, Weblate | We exceed coverage and add AI-locale aware backend |

## 8. Rollout

- Phase 0: en + pseudo-locale only, internal dogfood (1 week)
- Phase 1: 5 locales (es, pt-BR, fr, de, ja) at 100% — 2% beta
- Phase 2: Top 20 locales ≥80% — 10% rollout
- Phase 3: All 50 locales ≥60% — GA
- Kill switch: `feature.multi_language_50.enabled` (default on once shipped); falls back to en on any ARB load failure
- Per-locale flag: `feature.multi_language_50.locales.<code>` — disable a broken locale without redeploy

## 9. Translator Workflow (Crowdin / Weblate)

1. **Source of truth:** `mobile/lib/l10n/app_en.arb` — engineers add keys here only.
2. **CI hook:** on merge to main, GitHub Action `crowdin upload sources` pushes new keys.
3. **Glossary:** `crowdin/glossary.tbx` — 200 product terms (Server, Channel, Stage, Aura, Boost) marked DO-NOT-TRANSLATE or with locked translations.
4. **Screenshots:** Maestro test suite captures one screenshot per screen at every release; Crowdin CLI uploads with auto-tagged string IDs.
5. **Translator UI:** Crowdin web — volunteers see English source, screenshot, glossary tooltips, MT suggestion (DeepL free), and a Submit button.
6. **Review:** each locale has 1-2 reviewers; a string needs ≥1 approval before it lands.
7. **Sync back:** nightly `crowdin download translations` opens a PR `chore(l10n): sync from Crowdin <date>`.
8. **Vendor budget:** $0. Crowdin OSS plan free; DeepL MT 500k chars/mo free; we only pay if we exceed and we won't.
9. **Recognition:** translator names appear in `Settings > About > Translators` (auto-pulled from Crowdin).
10. **Fallback:** Weblate self-hosted instance at `weblate.flicko.app` mirrors the same flow for users who reject Crowdin TOS.
