# AI Emoji Suggester — APPFLOW

```mermaid
sequenceDiagram
    participant K as Keystroke
    participant C as Composer
    participant CL as Classifier (Dart)
    participant V as EmojiVectors

    K->>C: textChanged
    C->>C: debounce 100ms
    C->>CL: embed(text)
    CL-->>C: vector[300]
    C->>V: topK(vector, 3)
    V-->>C: ['😂','🤯','😅']
    C->>C: render chip row
    K->>C: tap chip
    C->>C: insert at cursor
```

## State Machine
```
[idle] → [embedding] → [showing] → [idle]
[idle] → [disabled] (setting off / model fail)
```

## Edge Cases
- Empty text: hide row.
- Suggestions identical to last keystroke: don't re-render.
- IME composition (CJK): suspend until composition ends.
- Voice-typed text: arrives as bursts; debounce 200ms when voice IME active.

## Background
- None.

## Notifications
- None.
