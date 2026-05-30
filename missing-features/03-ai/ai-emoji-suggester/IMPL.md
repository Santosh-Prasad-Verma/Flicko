# AI Emoji Suggester — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + model selection | 2 |
| 1 | Train + quantize fastText on emoji-tagged corpus | 4 |
| 2 | Precompute emoji vectors | 1 |
| 3 | Dart bindings + load test | 3 |
| 4 | Composer integration | 3 |
| 5 | Settings toggle + analytics | 2 |
| 6 | A11y + battery testing | 2 |
| 7 | Beta + GA | 2 |

## Tasks
- [ ] `tools/train-emoji/` Python project (fastText + emoji corpus)
- [ ] `mobile/assets/models/emoji-suggester-300d.bin`
- [ ] `mobile/assets/models/emoji-vectors.json`
- [ ] `mobile/lib/features/ai_assistant/emoji_suggester/{classifier.dart, suggester.dart, chips_widget.dart}`
- [ ] Provider: `emojiSuggesterProvider`
- [ ] Setting toggle in `mobile/lib/features/settings/presentation/chat_settings_screen.dart`
- [ ] L10n keys
- [ ] Optional analytics endpoint backend `POST /metrics/emoji-suggester` (rate-limited)
- [ ] Migration 135

## Files
```
mobile/assets/models/...                                                (new)
mobile/lib/features/ai_assistant/emoji_suggester/...                    (new)
mobile/lib/features/settings/presentation/chat_settings_screen.dart     (edit)
backend/internal/handlers/metrics_handler.go                            (edit, add endpoint)
supabase/migrations/135_ai_emoji_suggester.up.sql                       (new)
tools/train-emoji/                                                      (new)
```

## Test
- Top-1 precision ≥85% on held-out test set.
- Latency p99 <50ms on low-end Android.
- Battery soak: 1h of typing test ≤0.5% extra.

## Rollout
- Flag `feature.emoji_suggester.enabled`. Default ON.
- Beta on internal app build first.

## Risks
- Locale skew: monolingual model fails on CJK. Mitigation: language-agnostic emoji mapping fallback.

## Cost
- $0. App bundle adds ~600KB.
