# Smart Notifications - TRD

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                       Flicko Backend (Go)                          │
│  Existing: /api/v1/notifications  /api/v1/preferences              │
│  New:      /api/v1/preferences/notif/priorities (sync overrides)   │
└────────────────────────────────────────────────────────────────────┘
                            │ FCM / APNs
                            ▼
┌────────────────────────────────────────────────────────────────────┐
│                          Phone (Flutter)                           │
│                                                                    │
│  ┌──────────────┐   data-only push    ┌─────────────────────────┐ │
│  │ FCM/APNs     │ ───────────────────►│ NotifIngressService     │ │
│  └──────────────┘                     └────────────┬────────────┘ │
│                                                    │              │
│                                                    ▼              │
│                                       ┌────────────────────────┐  │
│                                       │ PriorityClassifier     │  │
│                                       │ (Riverpod)             │  │
│                                       └────────────┬───────────┘  │
│                                       on-device LLM call         │
│                                                    ▼              │
│       ┌────────────────────────────┐   ┌────────────────────┐    │
│       │ Tier? urgent | relevant |  │   │ DigestQueue        │    │
│       │       social   | noise    │   │ (Hive)             │    │
│       └────────┬─────────┬─────────┘   └────────┬───────────┘    │
│                │         │                      │                │
│       buzz now │         │ silent              │ next digest     │
│                ▼         ▼                      ▼                │
│       ┌────────────┐  ┌─────────┐      ┌────────────────────┐    │
│       │ NotifPlugin│  │ Inbox   │      │ DigestNotifBuilder │    │
│       │ (system)   │  │ (in-app)│      │ (system, hourly)   │    │
│       └────────────┘  └─────────┘      └────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
```

## 2. Components

### 2.1 NotifIngressService
- Hooks `firebase_messaging.onBackgroundMessage` and iOS Notification Service Extension.
- Fetches the message + parent thread + last 5 messages context for classification.
- Hands payload to `PriorityClassifier`.

### 2.2 PriorityClassifier
- Pluggable strategy:
  - `LLMClassifier` (preferred): wraps `google_mlkit_genai` (Android, Gemini Nano via AICore) or Mediapipe LLM Inference (iOS, Phi-3-mini-int4 ~ 1.4 GB downloaded once).
  - `HeuristicClassifier` (fallback): keyword + rules for older devices.
- Returns `{ tier, score, reason, latencyMs }`.

### 2.3 NotificationPolicy
- Decides delivery: buzz, silent inbox, digest queue, or DND-bypass ring.
- Combines per-channel override, quiet-hours config, and classifier output.

### 2.4 DigestQueue
- Buffers `social` and `noise` for periodic delivery (default hourly when not in quiet hours).
- Coalesces per channel: "12 messages in #random".

### 2.5 FeedbackCollector
- "Was this important?" thumbs in the in-app inbox.
- Updates per-channel and per-author bias weights stored locally.

## 3. On-Device Models

### 3.1 Android - Gemini Nano (AICore)
- API: `google_ai_edge_genai_flutter` (Mediapipe wrapper) or direct AICore via platform channel.
- Model: provided by OS on Pixel 8+, S24, etc.
- Latency: ~80-120 ms p50, ~180 ms p95.

### 3.2 iOS - Phi-3-mini-int4 via Mediapipe LLM Inference
- Bundle: downloaded on first launch from Flicko CDN (already used for Whisper models).
- Size: ~1.4 GB int4 quantized.
- Runs on Neural Engine via Core ML if available; falls back to GPU.
- Latency: ~150-250 ms p95 on iPhone 13+.

### 3.3 Heuristic Fallback
- Triggers when device fails capability check or latency p95 > 250 ms.
- Rules:
  - Direct mention or DM -> `relevant` minimum, `urgent` if author is in starred list.
  - Question marks + author starred -> `relevant`.
  - On-call labeled channel -> `urgent`.
  - All else -> `social` if <50 members, `noise` if >50.

## 4. Prompt Template

```
SYSTEM:
You classify a chat notification into one of: urgent, relevant, social, noise.
Output strictly JSON: {"tier":"...", "reason":"<= 60 chars"}.
Rules:
- urgent: direct DM, on-call, or unambiguous request to user by name.
- relevant: thread user joined, mention by name, question to channel where user is active.
- social: casual chat in active server.
- noise: bot messages, off-topic chatter, large server background.

USER:
Channel: {channel_name} ({channel_kind}, {member_count} members)
Author: {author_handle} (relationship: {relationship})
Time: {ts}
Last 5 messages context:
{context}
New message:
{body}
```

Output validated; non-conforming output triggers fallback to heuristic on this notification only.

## 5. REST/WS Surface

### 5.1 New Endpoints

#### `GET /api/v1/preferences/notif/priorities`
Returns per-channel/per-server overrides for the user.

```json
{
  "channels": [
    { "channel_id": "ch_oncall", "min_tier": "urgent", "bypass_dnd": true },
    { "channel_id": "ch_random", "max_tier": "noise" }
  ],
  "servers": [
    { "server_id": "srv_friends", "boost_tier": 1 }
  ],
  "quiet_hours": { "start": "22:00", "end": "07:00", "tz": "Asia/Kolkata", "min_tier": "urgent" },
  "digest_times": ["09:00", "13:00", "18:00"]
}
```

#### `PUT /api/v1/preferences/notif/priorities`
Idempotent upsert. Validated server-side; no model logic on backend.

### 5.2 Reused Endpoint
- `POST /api/v1/notifications/feedback` (existing, gains `tier_correction` field).

## 6. NFRs

| Property                         | Target                                |
|----------------------------------|---------------------------------------|
| Classifier latency p95           | < 180 ms (Android), < 250 ms (iOS)    |
| Classifier accuracy (eval set)   | >= 88% precision on `urgent`          |
| False-negative on `urgent`       | < 1.2%                                |
| Battery impact                   | <= 0.5% daily added                   |
| Binary size delta                | <= 8 MB Android, <= 4 MB iOS (model deferred to first-run download) |
| Memory peak during inference     | <= 350 MB                              |
| Offline behavior                 | Classification works fully offline    |

## 7. Observability

Telemetry events (via existing pipeline):

- `notif.received` { channel_kind, member_count_bucket }
- `notif.classified` { tier, source: llm|heuristic, latency_ms_bucket }
- `notif.delivered` { tier, route: buzz|silent|digest|dnd_bypass }
- `notif.feedback` { tier_before, tier_after }
- `notif.error` { code }

Aggregated, no message content ever leaves the device.

## 8. Privacy & Safety

- Inference is local. Model never sees a network.
- Telemetry contains buckets only (no message text, no author handles).
- "Why this?" screen surfaces the prompt and reason locally; not transmitted.
- DND-bypass requires explicit user opt-in per channel; we never enable it for them.

## 9. Failure Modes

| Failure                                  | Behavior                                                         |
|------------------------------------------|------------------------------------------------------------------|
| Model not yet downloaded                 | Heuristic for first session; show toast "Smart notifications activating soon" |
| Inference timeout (> 1 s)                | Treat as `relevant`; surface in feedback collector for review   |
| Malformed JSON output                    | Heuristic fallback for this message                              |
| Per-channel override conflicts           | Override wins; LLM result logged for debugging                   |
| OS killed background isolate             | Persist queue; classify on next foreground                        |

## 10. Backend Footprint

Migration `144_create_notification_priorities.up.sql` adds a small JSON-backed preferences table; no per-message storage backend-side. The classifier never runs on the server.
