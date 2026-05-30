# AI Moderation — APPFLOW

```mermaid
sequenceDiagram
    participant U as User
    participant API as Backend
    participant AM as AutoMod (regex)
    participant AI as AI Classifier
    participant DB as Supabase
    participant CH as Channel
    participant M as Mods

    U->>API: POST /messages
    API->>AM: regex check
    AM-->>API: pass
    API->>AI: classify(text, locale, channel_meta)
    AI-->>API: {hate:0.02, harassment:0.91, sexual:0.0, self_harm:0.0, violence:0.10}
    alt above block_threshold
      API->>DB: log mod_signal (blocked)
      API-->>U: 403 with reason
    else above review_threshold
      API->>CH: publish (with quiet flag)
      API->>DB: enqueue mod_queue
      API->>M: notify mods
    else clean
      API->>CH: publish
    end
```

## State Machine
```
message: [pending] → [classified] → [published] | [blocked] | [reviewing]
review: [open] → [approved] | [denied]
appeal: [open] → [overturned] | [upheld]
```

## Edge Cases
- Edits trigger reclassify; if borderline, hold edit.
- Forwarded messages: classify once at original.
- Slang/dialect false positive: per-language threshold tuning.
- Encrypted DMs: AI moderation never enabled (E2EE preserved).
- Mod marked safe: cache decision 30 days for that exact text hash to avoid re-flag.

## Background
- Threshold drift sweep weekly: alert mods if false-positive rate spikes.
- Re-train metadata report monthly.

## Notifications
- User: "Your message couldn't be sent because of our community guidelines. Appeal?"
- Mods: notification of new queue items, batched 5 min.
