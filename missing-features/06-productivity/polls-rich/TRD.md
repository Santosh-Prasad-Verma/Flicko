# Rich Polls — Technical Requirements

## 1. Architecture Overview

```
   ┌──────────────────────────────────────┐
   │ Mobile (Flutter)                     │
   │  PollComposer  PollWidget(channel)   │
   │  PollResultsScreen                   │
   └────────────┬─────────────────────────┘
                │ REST + Centrifugo
                ▼
   ┌──────────────────────────────────────┐
   │ Go Backend                           │
   │  polls_v2_service.go                 │
   │  irv_tabulator.go                    │
   │  anti_abuse.go                       │
   └────────────┬─────────────────────────┘
                ▼
   ┌──────────────────────────────────────┐
   │ Postgres                             │
   │  polls_v2  poll_questions  poll_votes│
   └──────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- `services/productivity/polls_v2/service.go`
- `services/productivity/polls_v2/irv_tabulator.go`
- `services/productivity/polls_v2/anti_abuse.go`
- `handlers/polls_v2/{poll_handler,vote_handler,results_handler}.go`
- `models/poll_v2.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/polls_rich/`
  - Composer, channel widget, results

### Infra
- DB: Postgres, migration 171
- Realtime: Centrifugo `polls:server:<sid>` events `poll.created`, `vote.added`, `poll.closed`
- Cron: `polls_v2_auto_close` every minute

## 3. API Contracts

### REST
```
POST   /api/v1/polls                              create
GET    /api/v1/polls?server=&channel=
GET    /api/v1/polls/:id                          (with my vote state)
POST   /api/v1/polls/:id/votes                    submit answers
DELETE /api/v1/polls/:id/votes                    retract (if allowed)
POST   /api/v1/polls/:id/close                    mod-only manual close
GET    /api/v1/polls/:id/results                  aggregates (post-close or live)
```

### Payloads
```jsonc
// Create
{
  "server_id":"uuid",
  "channel_id":"uuid",
  "title":"Pick our next event",
  "anonymous":true,
  "show_results":"live|on_close",
  "closes_at":"2026-06-12T20:00:00Z",
  "max_votes_per_user":1,
  "questions":[
    {"type":"single","label":"Pick one","options":["Game night","Movie","Trivia"]},
    {"type":"ranked","label":"Rank these","options":["Tue","Wed","Thu","Fri"]},
    {"type":"scale","label":"How important is timing 1-5","min":1,"max":5}
  ]
}
// Submit
{
  "answers":[
    {"qid":"uuid","value":{"choice":"Game night"}},
    {"qid":"uuid","value":{"ranking":["Fri","Thu","Tue","Wed"]}},
    {"qid":"uuid","value":{"scale":4}}
  ]
}
```

## 4. Permissions & Auth

- Create: any member by default; per-server override
- Vote: server members in scope channel
- View results: live always; on-close hides until closed
- Mod-only close

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Vote submit p99 | <120 ms |
| Tabulate IRV p99 | <300 ms (<=10k votes) |
| Throughput | 500 votes/sec |
| Storage | <$0.00005 per vote |

## 6. Dependencies

- Existing: messages (post poll widget), channels, server-members, audit-log
- Mobile: existing chart lib

## 7. Observability

- `flicko_polls_created_total{type}`
- `flicko_polls_votes_total{type}`
- `flicko_polls_irv_seconds` histogram
- `flicko_polls_active` gauge

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Anonymous collision | duplicate detection failure | per-poll salt SHA-256 |
| IRV tie | undefined winner | alphabetical tiebreaker; UI shows ties |
| Vote race | double vote | UNIQUE on `(poll_id, user_id)` |
| Mass voting bot | abuse | rate limit + member-only + minimum-account-age check |
| Late vote | confusion | reject 410 |
| Edit after votes | invalid state | block edits once any vote exists; revision bump only |
