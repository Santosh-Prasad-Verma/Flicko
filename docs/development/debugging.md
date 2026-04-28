# Full-Stack Debugging

> **Reading time:** ~7 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

When a user taps "Send Message" on the mobile app and nothing happens, the error could exist in React, the Network, NGINX, the Monolith, or PostgreSQL. Finding it quickly requires a systematic approach.

---

## 1. Tracing the Mobile Network (Reactotron)

Never use `console.log` for network tracing in Flutter. The output is stripped when Flutter caches the metro bundle, and scrolling through a terminal of giant JSON blobs is impossible.

We use **Reactotron**.
1. Download the Reactotron desktop client.
2. In the `mobile/` directory, ensure `reactotron.config.js` is imported in `App.tsx`.
3. The desktop client will automatically intercept every Dio request, WebSocket payload, and Riverpod state change.

**The Strategy:**
If a message fails, first check Reactotron's "Networking" tab. 
Did the app receive a `400 Bad Request` or a `500 Internal Server Error`?
- **400s:** Meaning the mobile app sent malformed JSON. The bug is in `frontend/`.
- **500s:** Meaning the API crashed. The bug is in `backend/`.

---

## 2. API STDOUT Auditing (Loki/Logfmt)

If Reactotron shows a `500`, look at the `X-Request-Id` header returned in the Dio payload (e.g. `c-9x2`).

The Go backend outputs logs using `logrus` formatted as Logfmt space-delimited text.
If you are running the API via Air locally, look at the terminal tab running `api` or `msg-service`.

**Searching production:**
If this happened on the live VPS, we use Grafana Loki.
Open Grafana -> Explore -> Loki.
Run the LogQL query:
```text
{app="flicko-msg-service"} |= "c-9x2"
```
This isolates the exact stack trace emitted by the Go binary right before the panic occurred, bypassing thousands of other concurrent requests.

---

## 3. Go Deep-Dive Debugging (`delve`)

If the error is an algorithmic bug (e.g. the Bitwise Permissions logic is calculating the wrong output), `console.log` testing is inefficient. We attach the standard Go debugger: `dlv`.

If you use VSCode:
1. Open `.vscode/launch.json`. We possess a configuration called `Debug API`.
2. Click the Play button in the VSCode debugging tab.
3. This launches the Go API using `dlv` instead of standard `go run`.
4. Click next to the line numbers in `permissions.go` to set a red breakpoint.
5. Trigger the API from Postman or the mobile app. The VSCode execution will pause perfectly on that line, allowing you to inspect the local variables in memory and step through iterations line-by-line using `F10`.

---

## 4. Database Deadlocks

Sometimes the API isn't crashing, but requests are hanging infinitely (`timeout`). This is usually an unreleased SQL transaction lock.

If you suspect a lock, connect directly to PostgreSQL via `psql` (or DBeaver) and run the `pg_stat_activity` diagnostic:

```sql
SELECT
    pid,
    usename,
    state,
    wait_event_type,
    wait_event,
    query
FROM pg_stat_activity
WHERE state = 'active'
AND query NOT ILIKE '%pg_stat_activity%';
```

Look for rows where `wait_event_type` is `Lock`. Once identified, you can either explicitly kill the locking PID via `SELECT pg_terminate_backend(pid);`, or track down the Go `sqlx.Tx{}` code block that failed to call `.Rollback()` inside its `defer` statement.
