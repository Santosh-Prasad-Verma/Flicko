# Esports Integration — TRD

## Architecture
```
PandaScore poller (cron 60s) → upsert esports_events → diff
   ↓
NATS flicko.esports.update → server-channel subscribers
   ↓
post/edit message embed (system-bot author)
```

## Components
- Backend: `backend/internal/services/gaming/esports/{poller.go, adapter_pandascore.go, dispatcher.go, subscriptions.go}`
- Handler: `esports_handler.go` — POST /servers/:id/channels/:cid/esports/subscriptions
- Existing message_handler used to author embeds via system-bot user
- pg_cron 60s tick

## API
```
POST /servers/:s/channels/:c/esports/subscriptions
  {game:'lol', team_id?:'12', league_id?:'5', kind:'live|schedule'}
GET  /servers/:s/channels/:c/esports/subscriptions
DELETE /esports/subscriptions/:id
GET  /esports/upcoming?game=lol&days=7
```

## NFRs
| NFR | Target |
|-----|--------|
| Latency | <60s after PandaScore |
| API quota | <30 calls/min |
| Channel update lag | <5s after detection |

## Observability
- `flicko_esports_pandascore_calls_total`
- `flicko_esports_subscriptions_total`
- `flicko_esports_dispatch_seconds`
- Alert on 429 rate.

## Failure
| Failure | Mitigation |
|---------|------------|
| PandaScore down | cache last status; retry 5 min |
| Quota hit | switch to longer interval per low-priority subs |
| Stale data | mark embed "as of HH:MM" |
