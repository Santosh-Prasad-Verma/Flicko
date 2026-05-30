# Catch-Me-Up — AI Channel Summary — App Flow

## 1. End-to-End Journey — Cache miss

```mermaid
sequenceDiagram
    participant U  as User (Flutter)
    participant API as Go Backend
    participant RL  as Redis (ratelimit + cache)
    participant DB  as Postgres (messages)
    participant L   as LLM (Groq | Ollama)
    participant CF  as Centrifugo

    U->>API: POST /api/v1/ai/summary/request {channel_id, since_ts}
    API->>API: validate ACL on channel
    API->>RL: ZADD summary:ratelimit:<u>  now
    RL-->>API: count=12/50 ok
    API->>DB: SELECT messages WHERE channel_id=$1 AND created_at > $2 LIMIT 500
    DB-->>API: 142 rows
    API->>API: compress (drop emoji-only, dedupe, total ~4800 tokens)
    API->>RL: GET summary:answer:<chan>:<anchor>:<latest>:<model>
    RL-->>API: nil (miss)
    API->>L: stream chat (prompts/summary.md + compressed window)
    L-->>API: token "•"
    API->>CF: publish summary:<req_id>  bullet idx=0 partial
    Note over L,CF: tokens stream …
    L-->>API: [DONE]
    API->>API: parse bullets + resolve message_id citations
    API->>CF: publish meta + done
    API->>DB: INSERT ai_summaries (final)
    API->>RL: SETEX summary:answer:<key> 3600 <json>
    API-->>U: 200 + stream_url (already consumed)
```

## 2. Cache hit (another member of same channel asks identical window 5 min later)

```mermaid
sequenceDiagram
    participant U
    participant API
    participant RL as Redis

    U->>API: POST /summary/request (same channel + same anchor)
    API->>RL: GET summary:answer:<key>
    RL-->>API: hit
    API-->>U: replay bullets via SSE (12ms each, simulates streaming)
    API->>API: emit cache_hit metric
```

Cache key is shared across users for the same `(channel_id, anchor_msg_id, latest_msg_id, model)` tuple — second viewer has near-instant TTFB.

## 3. Fallback to Ollama

```mermaid
sequenceDiagram
    participant API
    participant G as Groq
    participant O as Ollama
    API->>G: stream
    G--xAPI: 503 / timeout 8s
    API->>O: stream chat
    O-->>API: tokens
    API->>API: emit fallback metric
```

## 4. State Machine — UI

```
[hidden]
  -- unread >= 5  --> [pill_idle]
[pill_idle]
  -- tap          --> [requesting]
  -- scroll up    --> [dismissed]
  -- timeout 8s   --> [dismissed]
[requesting]
  -- 200 stream open --> [streaming]
  -- 429              --> [rate_limited]
  -- error            --> [error]
[streaming]
  -- bullet  --> [streaming]
  -- done    --> [done]
  -- error   --> [error]
[done]
  -- thumbs --> [done]
  -- ✕      --> [dismissed]
```

## 5. User Journeys

### J1 — Returning member after lunch
1. Alice opens Flicko 90 minutes after lunch.
2. `#general` shows 142 unread; pill `✦ Catch me up — 142 messages` floats above the unread bar.
3. Tap; pill morphs into card; first bullet appears in 1.1s.
4. After 4.5s the full 5-bullet card is rendered. She taps citation `[¹]` → bottom sheet → "Jump to thread".
5. Card stays visible until she scrolls up past the anchor.

### J2 — Long press partial summary
1. Bob long-presses a message from 6 hours ago in `#dev`.
2. Action sheet shows "Summarize from here".
3. Window starts at that message; runs as J1.

### J3 — Refused (too few)
1. Carl returns to `#niche-thread` which has 3 new messages.
2. No pill shown (threshold is 5). He scrolls and reads them.
3. If he forces summary via the channel header `⋯`, card shows "Not enough activity. Scroll up — there are only 3 messages."

### J4 — Rate-limited
1. Dave triggers his 51st summary today.
2. Pill becomes a static chip "Daily limit reached"; tap shows toast "Resets at midnight UTC."

## 6. Edge Cases

- **Permissions changed mid-window:** server middleware re-runs ACL on each request; if revoked, return `403`.
- **Messages deleted while summarizing:** parser drops missing citations; if a bullet has zero remaining citations, regenerate by asking LLM to re-cite from remaining message_ids (1 retry max).
- **User scrolls to anchor while loading:** card stays in the same DOM position relative to the unread separator; if user scrolls past it, the card scrolls with content normally.
- **Channel renamed mid-summary:** title in card updates on next render — anchor logic untouched.
- **Stream broken:** client polls `GET /summary/:id` after 5s of silence; if `outcome=done`, replay; else fallback to error UI.
- **User offline:** request never sent; pill shows offline indicator.
- **Channel marked NSFW:** model fallback to Ollama only — Groq has overly strict content policies; output still sanitized.
- **Channel is a voice channel:** pill never shows (voice-only).

## 7. Background / Async

- **Hot-summary cache warming:** every 5 min, a worker iterates top-50 channels by activity and pre-warms `summary:answer` for the rolling 24h anchor — yields 80% cache hit on demand.
  - Cron: `*/5 * * * *`
  - Subject: `flicko.ai.summary.warm`
  - Idempotency: `summary:warm:<channel_id>:<bucket-5min>`
  - Failure: skip channel, retry next bucket
- **Archive:** nightly job dumps `ai_summaries` rows older than 30d to R2 parquet; deletes from Postgres on success.

## 8. Notifications

- **Trigger:** opt-in "Daily catch-me-up" digest pushed at 09:00 local
  - Channel: push + in-app card on Home
  - Copy: `5 servers, 18 channels, here's what you missed`
  - Deep link: `flicko://digest/<date>`
  - Batching rule: 1 per day max
- v1 ships only the on-demand pill; daily digest is feature-flagged behind `feature.ai_summary_digest.enabled`

## 9. Sequence Diagram — Citation tap

```mermaid
sequenceDiagram
    participant U as User
    participant C as SummaryCard
    participant Sh as CitationPeekSheet
    participant Ch as ChannelMessagesScreen
    U->>C: tap [¹]
    C->>Sh: open with message_ids=[m1, m2]
    Sh-->>U: render preview
    U->>Sh: tap "Jump"
    Sh->>Ch: scroll to m1 + blink
    Ch-->>U: visible + brief highlight
```
