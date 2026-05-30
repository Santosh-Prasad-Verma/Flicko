# Auto-Translate — Inline Per-Message Translation — App Flow

## 1. End-to-End Journey — Cache miss

```mermaid
sequenceDiagram
    participant U  as User
    participant M  as Mobile
    participant API as Backend
    participant RL  as Redis
    participant L   as LID (fastText)
    participant LT  as LibreTranslate
    participant DP  as DeepL
    participant DB  as Postgres

    U->>M: tap "Translate"
    M->>API: POST /api/v1/ai/translate {text, tgt:"en"}
    API->>RL: ZADD translate:rate:<u>  now
    RL-->>API: count=43/1000 ok
    API->>L: detect(text)
    L-->>API: ja, conf=0.97
    API->>API: glossary mask -> __GLO_0__
    API->>RL: GET translate:cache:<sha>:<ja>:<en>
    RL-->>API: nil (miss)
    alt pair in {en<->ja, en<->ko, en<->zh} and quota<80%
      API->>DP: POST /v2/translate
      DP-->>API: 200 "Hello"
    else
      API->>LT: POST /translate
      LT-->>API: 200 "Hello"
    end
    API->>API: glossary unmask
    API->>RL: SETEX translate:cache:<sha>:<ja>:<en> 30d "Hello"
    API->>DB: INSERT translations_log (id, sha, src, tgt, provider, cached=false)
    API-->>M: 200 {translated:"Hello", provider:"deepl", cached:false}
    M-->>U: render bubble
```

## 2. Cache hit (different user, same text+pair)

```mermaid
sequenceDiagram
    participant API
    participant RL as Redis
    API->>RL: GET translate:cache:<sha>:<ja>:<en>
    RL-->>API: hit "Hello"
    API-->>M: 200 {translated:"Hello", cached:true} (~25ms total)
```

## 3. Provider fallback (DeepL quota exhausted)

```mermaid
sequenceDiagram
    participant API
    participant DP as DeepL
    participant LT as LibreTranslate
    API->>DP: translate
    DP--xAPI: 456 quota_exceeded
    API->>API: emit deepl_quota_exhausted, set Redis flag for 24h
    API->>LT: translate
    LT-->>API: 200
```

## 4. Auto-translate on incoming message (server has it ON)

```mermaid
sequenceDiagram
    participant M as Mobile
    participant API
    M->>M: receive new message (Centrifugo) text="こんにちは"
    M->>M: read user pref tgt="en", "always translate"
    M->>M: read server config auto_translate=true for channel
    M->>API: POST /translate {text,tgt:"en"} (debounced 200ms)
    API-->>M: 200 "Hello"
    M-->>M: render bubble auto+badge from cold
```

## 5. State Machine — translate inline

```
[hidden]
  -- need_translate --> [button]
[button]
  -- tap            --> [loading]
  -- swipe-dismiss  --> [hidden]    (3 dismisses suppresses for 24h)
[loading]
  -- 200 ok         --> [shown]
  -- 4xx/5xx        --> [error]
  -- 429            --> [quota]
[shown]
  -- "show original"--> [hidden]
  -- thumbs         --> [shown]
[error]
  -- retry          --> [loading]
[quota]
  -- midnight       --> [button]
```

## 6. User Journeys

### J1 — Happy path
1. Yuki posts a Japanese message in `#general`.
2. Alice (en pref) sees the `Aa Translate` button.
3. Taps; bubble expands in 320ms (cache hit) or 720ms (miss).
4. Reads Hello! How are you? — taps 👍.

### J2 — Auto-translate on
1. Server admin toggles auto-translate in `#intl`.
2. All en-pref members see translation bubble auto-rendered with `auto` badge.
3. Member sets `ja` as fluent → bubble disappears for ja messages.

### J3 — Glossary
1. Admin opens glossary, adds `Frostmourne`.
2. Future messages with that exact word keep it untranslated.
3. Round-trip CI test verifies `__GLO_0__` placeholder isn't translated.

### J4 — Quota
1. User hits 1000 translations today.
2. Buttons disabled with tooltip; original text fully readable.

## 7. Edge Cases

- Detection conf < 0.5 → no auto-translate; user picks source from dropdown.
- Code blocks: never translated (LID returns `code` heuristic; entire code block passes through unchanged).
- Mentions `<@user_id>` are placeholder-protected like glossary.
- Messages edited after translation: cache key changes, retranslated on next view.
- Same text re-cached at edit; old key TTL'd out.
- 5000+ char message: client-side truncation hint "Translate first 5000 chars?"
- LibreTranslate health-check polled every 10s; if down 3× consecutive, route all to DeepL until healed.
- DeepL daily quota counted in Redis incr; threshold alert at 80%.

## 8. Background / Async

- **Cache warmer:** cron `0 */6 * * *` — for top-1k high-traffic foreign messages, pre-translate to top-3 user-langs (en, es, ja). Fills cache so first viewer hits.
  - Subject: `flicko.ai.translate.warm`
  - Idempotency: `translate:warm:<msg_id>:<tgt>`
- **Eviction:** Redis natural TTL 30d.
- **Quota reset:** DeepL counter is daily; reset at midnight UTC via cron.

## 9. Notifications

None. Translation is silent.
