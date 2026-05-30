# AI Emoji Suggester — TRD

## Architecture
```
keystroke → debounce 100ms → classifier.embed(text) → top-K cosine vs emoji vectors → render chips
```

## Components
- Mobile: `mobile/lib/features/ai_assistant/emoji_suggester/{classifier.dart, suggester.dart, chips_widget.dart}`
- Model: quantized fastText `assets/models/emoji-suggester-300d.bin` (~400KB).
- Emoji vectors precomputed offline; shipped as `assets/models/emoji-vectors.json` (~150KB).
- No backend.

## API
- None. Pure client.
- Optional analytics POST for accept-rate (anonymous).

## NFRs
| NFR | Target |
|-----|--------|
| Inference | <30ms |
| Battery overhead/h typing | <0.5% |
| App bundle delta | ≤600KB |

## Observability
- `flicko_emoji_suggestions_shown_total` (client → batched server)
- `flicko_emoji_suggestions_accepted_total`
- Sampling rate 10%.

## Failure
- If model load fails: silently disable; fall back to existing emoji recents.
