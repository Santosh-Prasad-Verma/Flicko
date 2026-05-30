# AI Server Insights — TRD

## Architecture
```
weekly cron (Sun 09:00 server-local) →
  aggregate SQL queries against existing activity tables
  → JSON facts package
  → Groq summarizer (structured prompts; LLM only writes prose around facts)
  → store report
  → post message in mod channel + DM admins
```

## Components
- Backend: `backend/internal/services/ai/server_insights/{aggregator,patterns,summarizer,publisher}.go`
- Prompt template at `backend/internal/services/ai/server_insights/prompts/weekly.md`
- pg_cron scheduling.
- Existing message_handler used to author embeds via system-bot user.

## API
```
GET /servers/:id/insights              (latest)
GET /servers/:id/insights/:report_id   (historical)
POST /servers/:id/insights/run         (manual generate, Plus only)
```

## NFRs
| NFR | Target |
|-----|--------|
| Report generation | <60s |
| Cost / report | <$0.01 |
| Data freshness | last completed week |

## Observability
- `flicko_ai_insights_runs_total{status}`
- `flicko_ai_insights_seconds`
- `flicko_ai_insights_suggestions_total{action}`

## Failure
- Aggregator slow: timeout 30s; ship partial with warning.
- LLM down: ship template-only report; retry later.
- Server too small: skip report for <50 active members week.
