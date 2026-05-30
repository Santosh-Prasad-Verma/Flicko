# AI Image Generation — APPFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant API as Backend
    participant Q as Quota
    participant F as Filter
    participant P as Pollinations
    participant N as NSFW Classifier
    participant S as Appwrite
    participant CH as Channel

    U->>API: /imagine cat astronaut, style:anime
    API->>Q: check user quota
    Q-->>API: ok 4/5 left
    API->>F: prompt safety check
    F-->>API: ok
    API->>P: GET /prompt/<encoded>?model=flux&width=1024&height=1024
    P-->>API: image bytes
    API->>N: classify
    N-->>API: safe
    API->>S: store original
    API->>CH: post embed message {url, prompt, style}
    API-->>U: 200 OK
    Note over U,CH: re-roll / variations same flow
```

## State Machine
```
[queued] → [filtering] → [generating] → [moderating] → [posted]
                                       \→ [blocked]
                                       \→ [failed]
```

## Edge Cases
- Pollinations rate-limit: switch to SDXL fallback automatically.
- Prompt contains person name → block per-policy.
- Prompt has only emojis: minimum 3 words required.
- Image upload >10 MB: reject; reduce dimensions.
- User cancels mid-gen: best-effort cancel, no quota refund unless <1s.

## Background
- Async path via NATS for cold-start SDXL warm-up if Pollinations slow.
- Quota reset 00:00 user-local.

## Notifications
- "Image is ready" inline only (no push).
