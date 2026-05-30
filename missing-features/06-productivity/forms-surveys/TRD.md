# Forms & Surveys — Technical Requirements

## 1. Architecture Overview

```
   ┌─────────────────────────────────────────────┐
   │ Mobile (Flutter)                            │
   │  FormBuilderScreen   FormFillScreen         │
   │  ResponsesDashScreen                        │
   └────────────┬────────────────────────────────┘
                │ REST + Centrifugo
                ▼
   ┌─────────────────────────────────────────────┐
   │ Go Backend                                  │
   │  forms_service.go                           │
   │  responses_service.go                       │
   │  validator.go                               │
   │  aggregator.go                              │
   │  csv_export.go                              │
   └────────────┬────────────────────────────────┘
                ▼
   ┌─────────────────────────────────────────────┐
   │ Postgres                                    │
   │  forms  form_questions  form_responses      │
   │  form_response_answers                      │
   └─────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- `services/productivity/forms/service.go`
- `services/productivity/forms/validator.go`
- `services/productivity/forms/aggregator.go`
- `services/productivity/forms/csv_export.go`
- `handlers/forms/{form_handler,response_handler,export_handler}.go`
- `models/form.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/forms_surveys/`
  - Builder, fill, dashboard screens

### Infra
- DB: Postgres, migration 169
- Realtime: Centrifugo `forms:server:<sid>` for `response.added`
- Storage: Appwrite bucket `form-attachments`

## 3. API Contracts

### REST
```
POST   /api/v1/forms                           create
GET    /api/v1/forms?server=&channel=
GET    /api/v1/forms/:id                       form + question schema
PATCH  /api/v1/forms/:id                       update (only when state=draft)
POST   /api/v1/forms/:id/publish               draft -> open
POST   /api/v1/forms/:id/close                 -> closed
POST   /api/v1/forms/:id/archive               -> archived
POST   /api/v1/forms/:id/responses             submit answer set
GET    /api/v1/forms/:id/responses             list (admin)
GET    /api/v1/forms/:id/responses.csv         CSV export
GET    /api/v1/forms/:id/aggregates            chart data
```

### Payloads
```jsonc
// Create form
{
  "server_id":"uuid",
  "channel_id":"uuid",
  "title":"Event Feedback",
  "description":"Took 2 minutes",
  "questions":[
    {"type":"short_text","label":"Name","required":false},
    {"type":"choice_single","label":"Rating","options":["1","2","3","4","5"],"required":true},
    {"type":"choice_multi","label":"What did you enjoy?","options":["Talks","Food","Networking"]},
    {"type":"long_text","label":"Comments"}
  ],
  "anonymous":false,
  "limit_one_per_user":true,
  "closes_at":"2026-06-15T00:00:00Z"
}
// Submit
{ "answers": [{ "qid":"uuid","value":"3" }, ... ] }
```

## 4. Permissions & Auth

- Mods create forms; members fill
- Anonymous mode hashes user_id with form-specific salt
- RLS: members can read open forms in their channels

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Submit p99 | <150 ms |
| Aggregate query p99 | <200 ms |
| Throughput | 200 rps submits |
| Storage | <$0.0002 per response |

## 6. Dependencies

- Existing: messages (post link to form), channels, server-members
- Mobile: chart lib `fl_chart: ^0.69.0`

## 7. Observability

- `flicko_forms_published_total`
- `flicko_forms_responses_total{form_id}`
- `flicko_forms_submit_seconds` histogram
- `flicko_forms_export_total`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Schema change after responses | corrupt aggregate | edits blocked once state=open; allow only minor (label fix) via `revision` bump |
| Anon collision | wrong "one per user" | salted SHA-256 per form |
| Late submit (after close) | confusion | reject 410 |
| Large CSV | timeout | stream response with chunked encoding |
| Required field missing | bad UX | client validation + server validation |
