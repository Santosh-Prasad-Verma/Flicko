# Aura — Server-Aware AI Chat Assistant — Product Requirements

> **One-line:** Channel-mention `@Aura` for a context-aware AI agent that knows the server.
> **Status:** Missing — to build
> **Category:** 03-ai
> **Effort:** XL
> **Priority:** P0

## 1. Problem

Discord's MEE6 / Carl-bot / Probot have static FAQ commands; users repeat the same questions ("where are the rules?", "how do I get verified?", "what's the meeting time?") and admins burn out answering them. Slack's AI is paywalled at $10/user/mo and doesn't read the channel-pinned context. Notion AI is per-document only.

Flicko has community servers (gaming guilds, study groups, indie dev shops) where 60% of mod messages are answers to repeated FAQ. Forum thread "AI bot that actually reads our pinned messages?" has 1.4k upvotes on r/discordapp. Internal pilot servers report 35% of `#general` traffic is FAQ-shaped.

We need an AI agent that grounds replies in **this server's** corpus (FAQ docs, pinned messages, last 30d of activity) and gracefully says "I don't know" when out of scope.

## 2. Users & Use Cases

- **Primary persona:** Community moderator running a 500-5000 member server who is tired of answering "what's the wifi password / event time / role list".
- **Secondary persona:** New member who joined 2 minutes ago and is confused by 12 channels.
- **Tertiary persona:** Solo founder using a Flicko server as a customer-support inbox.

**Top 3 jobs-to-be-done:**
1. As a member, I want to mention `@Aura where is the rules channel?`, so that I get an instant answer instead of waiting for a mod.
2. As a mod, I want to drop a Markdown FAQ into Aura's knowledge so members self-serve, so that my notification load drops.
3. As a server owner, I want Aura to answer in the server voice (formal vs casual) and refuse off-topic, so that it feels native.

## 3. Goals & Non-Goals

**Goals**
- Per-server grounding (FAQ docs uploaded by admin, pinned messages auto-indexed, last 30d searchable).
- `@Aura` mention triggers reply in-thread within p50 < 2s first token.
- Zero hallucinations on out-of-scope: must refuse with "I don't have that in this server's docs."
- $0 marginal cost per reply via Groq free tier (llama-3.3-70b) with Ollama (`llama3.1:8b`) self-hosted fallback.

**Non-Goals (out of scope for v1)**
- DMs with Aura (v2).
- Voice-channel speech (handled by `ai-voice-transcription`).
- Cross-server memory (privacy-by-design — strictly per-server).
- Tool use (web search, code exec) — v2.

## 4. Scope (v1)

- [ ] `@Aura <prompt>` mention handler in any text channel
- [ ] Server-scoped knowledge base: upload `.md` / `.pdf` / `.txt` (max 50 docs, 5MB each)
- [ ] Auto-index pinned messages and channel descriptions
- [ ] Streaming reply (token-by-token via SSE → Centrifugo)
- [ ] "Why did you say that?" — show source citations as superscript
- [ ] Per-server admin panel: model picker, persona blurb, rate-limit
- [ ] Daily per-user cap: 30 mentions / day / server
- [ ] Refusal phrasing audited via golden eval set (50 in/out cases)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% servers with ≥1 Aura msg / week) | 40% within 60d | PostHog event `aura_invoked` |
| Reply quality (thumbs-up rate) | ≥75% | inline 👍/👎 widget |
| Hallucination rate on adversarial set | <2% | weekly eval run on `evals/aura/golden.jsonl` |
| First-token latency p50 / p95 | 1.2s / 3.5s | Prometheus `flicko_ai_chat_assistant_ttft_seconds` |
| Cost per reply | $0 (Groq free) | infra |
| Mod time saved (self-reported) | ≥2h / week / server | quarterly survey |
| % refusals correctly issued | ≥95% on out-of-scope set | eval |

## 6. Open Questions / Risks

- **Risk:** Groq free tier rate limit (30 req/min/key). Mitigation: pool of 5 keys via round-robin, fallback to Ollama after `429`.
- **Risk:** Indexing PDFs of TOS / NDA the server doesn't realize is sensitive. Mitigation: admin must explicitly add each doc; show "indexed" badge; `/aura forget <doc>` removes within 60s.
- **Question:** Should Aura see DMs sent in same server? Decision: NO. Channel-only.
- **Question:** Multiple personas per server (Aura-Support vs Aura-Lore)? Decision: v2.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord Clyde (deprecated 2024) | Generic, no per-server grounding, Discord killed it | Per-server RAG that *actually* answers from your docs |
| MEE6 | Static FAQ commands, manually authored | Aura ingests Markdown — no command authoring |
| Slack AI | $10/user/mo, channel summaries only, no QA | Free, server-grounded QA |
| Notion Q&A | Locked to Notion workspace docs | Lives where the conversation happens |
| Discord Probot | Custom `?faq` keyword matching | Semantic understanding via embeddings |
| ChatGPT free | No server context, must copy/paste | Native to Flicko, sees pinned + FAQ |

## 8. Rollout

- Week 1-2: Internal Flicko-Team server only.
- Week 3: 1% of waitlisted servers (50 servers max).
- Week 4: 10% with `aura.public_beta` flag.
- Week 6: GA, default OFF; admin opts in via Server Settings → AI → Enable Aura.
- Kill switch flag: `feature.ai_chat_assistant.enabled` in Doppler. Server-level toggle in `server_ai_settings.aura_enabled`.

## 9. Compliance

- GDPR: indexed docs are PII unless admin marks otherwise; right-to-erasure cascades from `users.delete` to remove user-authored prompts only (server-owned docs persist).
- DPA: Groq is a US sub-processor; EU servers fall back to self-hosted Ollama (no data leaves Hetzner-EU).
- Audit log: every `@Aura` mention is logged in `audit_logs` with `event=ai.aura.invoked`.
