# Smart Notifications - APPFLOW

## 1. End-to-End Notification Flow

```mermaid
sequenceDiagram
    participant BE as Flicko Backend
    participant Push as FCM / APNs
    participant Ingress as NotifIngressService
    participant CLS as PriorityClassifier
    participant Pol as NotificationPolicy
    participant OS as System Notif
    participant Inbox as In-App Inbox
    participant Digest as DigestQueue

    BE->>Push: data-only push
    Push->>Ingress: deliver payload
    Ingress->>Ingress: hydrate context (last 5 msgs, channel meta)
    Ingress->>CLS: classify(payload, context)
    alt LLM available
        CLS->>CLS: run on-device LLM
    else fallback
        CLS->>CLS: run heuristic
    end
    CLS-->>Ingress: {tier, reason, latency}
    Ingress->>Pol: decide(tier, overrides, quiet_hours)
    alt buzz now
        Pol->>OS: post system notification
        Pol->>Inbox: append to inbox
    else silent
        Pol->>Inbox: append to inbox
    else digest
        Pol->>Digest: enqueue
    else dnd_bypass
        Pol->>OS: post critical notification
        Pol->>Inbox: append
    end
```

## 2. Digest Delivery Flow

```mermaid
sequenceDiagram
    participant Sched as WorkManager / BGTaskScheduler
    participant Digest as DigestQueue
    participant OS as System Notif
    participant Inbox as In-App Inbox

    Sched->>Digest: tick (hourly or at scheduled time)
    Digest->>Digest: read pending entries
    alt count == 0
        Digest-->>Sched: no-op
    else count > 0
        Digest->>Digest: coalesce per channel
        Digest->>OS: post grouped notification
        Digest->>Inbox: mark entries delivered
        Digest->>Digest: clear queue
    end
```

## 3. Feedback Loop Flow

```mermaid
sequenceDiagram
    participant User
    participant InboxUI as Inbox / Why screen
    participant Feedback as FeedbackCollector
    participant Bias as Local Bias Store

    User->>InboxUI: tap thumbs (down / up / mark urgent)
    InboxUI->>Feedback: record(messageId, tierBefore, tierAfter)
    Feedback->>Bias: update author_score, channel_score
    Feedback-->>InboxUI: show "Got it. We'll calibrate."
    Note over Bias: next classification consults bias before LLM call
```

## 4. State Machine - Notification Lifecycle

```
                  ┌────────────┐
   push received ►│  RECEIVED  │
                  └─────┬──────┘
                        │ classify
                        ▼
                  ┌────────────┐
                  │ CLASSIFIED │
                  └─────┬──────┘
        ┌───────────────┼─────────────────┐
        ▼               ▼                 ▼
  ┌──────────┐    ┌──────────┐      ┌────────────┐
  │  BUZZED  │    │ INBOXED  │      │ QUEUED FOR │
  │ (urgent /│    │ (silent) │      │   DIGEST   │
  │ relevant)│    └──────────┘      └─────┬──────┘
  └────┬─────┘                            │
       │ tap                              │ digest tick
       ▼                                  ▼
  ┌──────────┐                       ┌──────────┐
  │  OPENED  │                       │ DELIVERED│
  └────┬─────┘                       │  (group) │
       │ feedback                    └─────┬────┘
       ▼                                   │
  ┌────────────┐                           │
  │CALIBRATED  │                           │
  └────────────┘                           │
                                           ▼
                                      ┌──────────┐
                                      │  OPENED  │
                                      └──────────┘
```

## 5. Quiet Hours Decision

```mermaid
flowchart TD
  A[New notification, tier=T] --> B{In quiet hours now?}
  B -- no --> C[Apply normal policy]
  B -- yes --> D{T >= quiet.min_tier?}
  D -- yes --> E{Bypass DND opted in & T = urgent?}
  E -- yes --> F[Critical notification]
  E -- no --> G[Standard notification]
  D -- no --> H[Inbox or digest]
```

## 6. Edge Cases

### 6.1 Model Not Downloaded Yet
- iOS: show download progress in Settings; classification falls back to heuristic.
- Android: AICore not provisioned -> heuristic permanently on this device.

### 6.2 Offline (Push Still Possible via FCM/APNs)
- Push payload is data-only; we have full context cached locally for the channel.
- Classification runs offline. If context is missing, default to `relevant` (cautious).

### 6.3 Watch Disconnect During Buzz Decision
- Policy doesn't depend on watch presence. Phone always classifies and delivers locally.

### 6.4 Low Battery (<15%)
- Classifier disabled; heuristic only. Banner in settings.

### 6.5 OS Killed Background Isolate
- Notifications missed during the kill are reclassified on next foreground from server state.

### 6.6 LLM Returns Invalid JSON
- Single-message fallback to heuristic. Counter increments; if >5% of recent classifications fail, switch heuristic-default for 24 h and surface a status banner.

### 6.7 Override Conflicts (channel says urgent, classifier says noise)
- Override wins. LLM tier kept in inbox metadata for debugging.

### 6.8 User Spams Feedback (gaming)
- Bias deltas clamped per author/channel/day. Excessive corrections do not invert tiers within one message.

### 6.9 Time-Zone Change
- Quiet hours are stored with explicit `tz`. On TZ change we keep the displayed wall-clock window unchanged.

### 6.10 Notification Burst (>20 in 60 s)
- Coalesce into a single "burst" notification with summary; individual entries still classified.

### 6.11 Critical-Alert Entitlement Denied (iOS)
- DND-bypass requested but unavailable; UI explains and offers to direct user to Settings.

### 6.12 Digest Window Skipped (device asleep)
- Next foreground triggers a catch-up digest with combined entries.

## 7. Initialization Sequence

```mermaid
sequenceDiagram
    participant App
    participant Cap as CapabilityCheck
    participant Mod as ModelManager
    participant CLS as PriorityClassifier

    App->>Cap: probe device (Android API, AICore? iOS chip?)
    Cap-->>App: {llm: true|false, why: "..."}
    alt llm true
        App->>Mod: ensureModelReady()
        Mod-->>App: ready / downloading / failed
        App->>CLS: configure(LLMClassifier)
    else
        App->>CLS: configure(HeuristicClassifier)
    end
    App->>App: hydrate user prefs from /preferences/notif/priorities
```
