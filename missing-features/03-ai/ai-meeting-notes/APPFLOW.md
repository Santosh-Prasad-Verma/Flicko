# AI Meeting Notes — APPFLOW

```mermaid
sequenceDiagram
    participant LK as LiveKit
    participant API as Backend
    participant W as Worker
    participant WS as Whisper
    participant GR as Groq
    participant DB as Supabase
    participant CH as Channel

    LK-->>API: webhook participant_count==0 / session_ended
    API->>API: check eligibility (≥3 min, ≥2, opt-in)
    API->>LK: Egress fetch audio
    LK-->>API: m3u8 / mp3
    API->>W: enqueue NATS flicko.ai.notes
    W->>WS: transcribe (with diarization)
    WS-->>W: transcript JSON
    W->>GR: summarize {transcript}
    GR-->>W: {summary, decisions, action_items, follow_ups}
    W->>DB: insert meeting_notes + action_items
    W->>CH: post message embed (notes summary + view-full link)
    W->>API: emit Centrifugo event
    API->>CH: notify users mentioned in action items
```

## State Machine
```
[triggered] → [fetching] → [transcribing] → [summarizing] → [published]
              \→ [failed] (any step)
              \→ [skipped] (ineligible)
```

## Edge Cases
- Multiple sessions back-to-back: debounce 60s.
- Session with one speaker for whole time: still produces notes, marked "monologue".
- Audio missing (Egress fail): post "transcript unavailable" with no summary.
- User leaves and rejoins: counts as one session if gap <2 min.

## Background
- Cleanup raw audio after summary published (privacy).
- Retain transcript and summary 90d default; admin can extend.

## Notifications
- "Meeting notes ready in #standup" → push for participants only.
- Mentioned users for action items get individual notifications.
