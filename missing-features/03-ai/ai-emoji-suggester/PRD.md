# AI Emoji Suggester — PRD

> **One-line:** As-you-type emoji suggestions in the message composer using a tiny on-device classifier.
> **Effort:** S · **Priority:** P2

## Problem
Picking the right emoji means stopping typing, opening the picker, scrolling. A subtle inline suggester accelerates expressive chat while staying out of the way.

## Users
- Anyone typing in chat / comments.

JTBDs:
1. Type "lol", see 🤣 suggested above the keyboard, tap to add.
2. Type a sentence, get one accent emoji suggestion at the end.

## Goals
- <50ms latency per keystroke.
- On-device only (no server call).
- 90% precision on top-1 against held-out tests.

## Scope
- [ ] On-device classifier in Flutter
- [ ] Composer chip row with up to 3 suggestions
- [ ] Accept via tap; dismiss via swipe
- [ ] Settings toggle

Non-goals: Server-side LLM emoji rec (cost). Custom emoji ranking (use existing recents).

## Metrics
- Composer latency p99 unaffected (no regression).
- 25% of suggestions accepted when shown.
- Toggle-off rate <5% (a sign of annoyance).

## Risks
- Classifier model size in app bundle. Mitigation: <500KB quantized fastText.
- Locale support. Mitigation: language-agnostic embedding model.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| iOS keyboard | OS-level | Per-app context |
| Slack | Yes | Faster, on-device |
| Discord | None | Greenfield |
