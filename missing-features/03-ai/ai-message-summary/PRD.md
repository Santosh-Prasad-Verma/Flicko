# Catch-Me-Up — AI Channel Summary — Product Requirements

> **One-line:** One-tap "Catch me up" button summarizes a channel since your last visit.
> **Status:** Missing — to build
> **Category:** 03-ai
> **Effort:** L
> **Priority:** P0

## 1. Problem

Active Flicko channels can produce 200–2000 messages per day. A user returning after lunch / tomorrow / from vacation faces a wall of text. Discord's only tool is the unread-bar; users either scroll back endlessly, give up, or ask "what did I miss?" and burden the channel.

Slack's "Recap" charges $10/user/mo. Discord's experimental summary in 2024 only landed for partner servers and was canceled. Flicko users in our beta survey ranked "summary of what I missed" as the #2 most-wanted AI feature (after `@Aura`).

We need a free, private, fast summary anchored at a user's last-read marker, streamed token-by-token, with jump-to-message links.

## 2. Users & Use Cases

- **Primary persona:** Active member of a 500–5000 person server who reads 4-6 channels a day.
- **Secondary persona:** Lurker who opens Flicko once daily and wants a digest across servers.
- **Tertiary persona:** Mod returning from PTO catching up on a week of reports.

**Top 3 jobs-to-be-done:**
1. As a returning member, I want a 5-bullet summary of what happened since I left, so that I can decide what to read.
2. As a digest reader, I want a daily across-server summary, so that I never feel behind.
3. As a mod, I want each summary bullet to link back to the source message, so that I can verify before acting.

## 3. Goals & Non-Goals

**Goals**
- "Catch me up" button anchored to user's last-read in any channel
- Streamed bullet output (SSE) — first bullet < 1.5s
- Each bullet cites at least one source message via deep link
- Cache identical-window summaries across users (anchor key + window)
- $0 marginal cost via Groq free tier with Ollama fallback

**Non-Goals**
- Editable summaries (read-only)
- Cross-channel "everything you missed" digest in v1 (v2)
- Summarizing voice channels (handled by `ai-meeting-notes`)
- DMs / private threads (privacy-first, opt-in v2)

## 4. Scope (v1)

- [ ] Floating "✦ Catch me up" pill above the unread separator in `ChannelMessagesScreen`
- [ ] Backend windowing: from `last_read_at` to `now()`, max 500 messages or 24h, whichever first
- [ ] Streaming SSE → Centrifugo channel `summary:<request_id>`
- [ ] Bullet format: 3–7 bullets + key participants + sentiment label
- [ ] Each bullet → `flicko://channel/<id>/message/<id>` deep link
- [ ] Per-user daily cap: 50 summaries / day across all servers
- [ ] Cache by `(channel_id, anchor_message_id, latest_message_id)` — TTL 1h
- [ ] Refusal copy when channel has < 5 messages in window

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption: % DAU clicking summary ≥1×/week | 30% within 30d | PostHog `summary_invoked` |
| Repeat usage (W4) | 50% | cohort |
| Thumbs-up rate | ≥80% | inline feedback |
| First-bullet latency p50 / p95 | 1.5s / 4s | `flicko_ai_message_summary_ttfb_seconds` |
| Cost per summary | $0 | infra |
| % summaries with broken citation links | <0.1% | nightly QA crawl |

## 6. Open Questions / Risks

- **Q:** Show across server tabs as a "What did I miss" daily card? Decision: defer to v2.
- **Risk:** Channels with rapid emoji-only messages summarize poorly. Mitigation: filter out reaction-only / emoji-only msgs from window.
- **Risk:** Summarizing a channel where the user lacks read perms. Mitigation: window respects channel ACLs server-side.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord (canceled) | Rolled out then withdrew, nitro-only | Free, GA, all servers |
| Slack Recap | Channel summary, paywalled | Free + per-anchor (your unread point) |
| Notion AI | Doc summary, no chat | Live channel summary |
| Telegram | None | Bullet+citations format |
| Microsoft Teams | "Summarize meeting", not chat | Anchored to your last-read |

## 8. Rollout

- Internal dogfood (1 week)
- 5% of DAU behind `feature.ai_message_summary.enabled`
- Ramp 5 → 25 → 100% over 14d
- Kill switch: Doppler flag toggles handler to 503

## 9. Compliance

- Audit log: `ai.summary.invoked` with `channel_id`, `window_start`, `window_end`, `model_used`
- GDPR delete: cascade summaries by `requested_by`
- Retention: 30d hot, archive to R2 monthly
