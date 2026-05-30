# Auto-Translate — Inline Per-Message Translation — Product Requirements

> **One-line:** One-tap auto-translate any message into your preferred language.
> **Status:** Missing — to build
> **Category:** 03-ai
> **Effort:** M
> **Priority:** P0

## 1. Problem

Flicko's user base is 38% non-English (Spanish, Hindi, Portuguese, Japanese, French, German, Arabic). Cross-language servers are common: a gaming guild with members in 6 countries, a study group sharing Japanese resources, a startup with EU + LATAM teams. Currently users copy-paste into Google Translate, breaking flow and exposing private chat.

Discord has no native inline translate. Slack offers translate via paid Workflow Builder. Telegram has button per message but only via 3rd-party bots. Notion does paragraph-level translate inside docs only.

We need: inline, opt-in, free, private translation, with language detection and a per-user default target language. Self-host LibreTranslate to keep it $0 and EU-private.

## 2. Users & Use Cases

- **Primary persona:** International member in mixed-language community server.
- **Secondary persona:** Mod who needs to read user reports in many languages.
- **Tertiary persona:** Language learners using Flicko to chat with native speakers.

**Top 3 jobs-to-be-done:**
1. As a member, I want to tap a message in Japanese and see it in English, so that I can understand without leaving the app.
2. As a server admin, I want to enable auto-translate for the whole server, so that members feel included.
3. As a privacy-conscious user, I want my messages translated locally without going to Google, so that my conversation stays in our infra.

## 3. Goals & Non-Goals

**Goals**
- Per-message tap-to-translate with cached result
- Auto-detect source language (fastText 176-lang model)
- Per-user default target language
- Server-level "translate all" toggle (admin)
- Self-hosted LibreTranslate primary (45 langs); DeepL Free fallback (≥30 langs, 500k chars/mo free)
- Cache hash-keyed translations; second viewer gets instant result
- Glossary support (per-server, e.g. don't translate "Frostmourne")

**Non-Goals**
- Real-time translate-as-you-type (v2)
- Voice translate (handled by `ai-voice-transcription` + `ai-meeting-notes`)
- OCR translate of image attachments (v2)

## 4. Scope (v1)

- [ ] Long-press / kebab menu → "Translate" on any message
- [ ] Inline button "Auto-detect → en" appears under message if source ≠ user's preferred language and feature ON
- [ ] Backend translate API: `POST /api/v1/ai/translate`
- [ ] Cache: `(text_hash, src, tgt) → translation` for 30d
- [ ] Server admin: enable/disable per channel, configure source/target whitelist
- [ ] Per-user setting: target language; auto-translate threshold (always, never, ask)
- [ ] Per-server glossary (max 200 terms): "skip these phrases"
- [ ] Daily user cap: 1000 translations/day (counts against shared quota)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption: % servers with ≥1 translate event/week | 25% within 60d | PostHog `translate_invoked` |
| Quality (BLEU-2 vs DeepL on sample) | ≥0.62 | offline eval |
| Latency p50 / p95 | 350ms / 900ms | `flicko_ai_translate_latency_seconds` |
| Cache hit ratio | ≥60% | metric |
| Cost per translation | $0 | infra |
| % users setting target lang ≠ default en | 30% | settings |

## 6. Open Questions / Risks

- **Q:** Show original-vs-translated side by side or replace? Decision: replace, with toggle to show original.
- **Risk:** LibreTranslate quality is below DeepL for rare pairs (Japanese↔English). Mitigation: route through DeepL Free for top-quality pairs (en↔ja, en↔ko) until quota; LibreTranslate everything else.
- **Risk:** Glossary collision with general words (server emote `pog` ≠ english "pog"). Mitigation: glossary terms are case-sensitive and require word-boundary regex.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None native | Inline native button |
| Slack | Workflow Builder paid | Free, free tier |
| Telegram | 3rd-party bots only | Native + cached + private |
| Microsoft Teams | Translator built-in, MS-cloud | Self-hosted = EU-private |
| Notion | Paragraph translate in docs | Chat translate |

## 8. Rollout

- Beta: 5% with `feature.ai_auto_translate.enabled`
- Canary: 5 → 25 → 100% over 14d
- Per-server toggle defaults OFF (manual translate works); admins enable auto-translate for inclusivity

## 9. Compliance

- Audit: `ai.translate.invoked` (sampled 1%)
- Retention: cache 30d, request log 7d
- GDPR delete: cascade by `requested_by`
- Data residency: EU users stay on Hetzner-EU LibreTranslate; never DeepL for EU rows
