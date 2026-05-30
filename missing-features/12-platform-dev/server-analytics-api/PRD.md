# PRD: Server Analytics API

## Problem
Server owners and community managers operating mid-to-large Flicko servers need programmatic access to their server's metrics. Today, the only way to view engagement data is the in-app dashboard, which renders aggregate counters with no export, no historical drill-down, and no way to feed data into external BI tools (Looker, Metabase, Grafana). Power users have asked for a stable REST surface so they can build custom retention reports, monitor channel health from CI, and prove engagement to sponsors.

## Goals
- Ship a versioned, public REST API at `/api/v1/analytics/servers/{server_id}/...` that exposes server-scoped metrics with consistent shape.
- Provide signed CSV/JSON exports for offline analysis. Exports must be generated asynchronously (jobs table) so requests never block on slow aggregations.
- Enforce per-token rate limits so a runaway script cannot starve the rest of the platform.
- Back hot read paths with materialized views so a query for "messages per channel per day for the last 90 days" returns in under 250 ms p95.

## Non-Goals
- User-level analytics (individual member behavior) is out of scope; that lives in the safety/audit surface.
- Real-time streaming (websocket push of metrics) is not part of v1. Polling is fine.
- Cross-server aggregation (platform-wide) is reserved for internal admin tooling.

## Target Users
- Server owners on the Pro tier who want sponsor-facing engagement reports.
- Community ops teams who already use external dashboards and want Flicko to be a first-class data source.
- Third-party bot developers building moderation or growth tools that need server health signals.

## Success Metrics
- 200+ unique servers calling the API monthly within 90 days of GA.
- p95 latency under 250 ms for cached endpoints, under 2 s for ad-hoc aggregations.
- Export job success rate above 99 percent (failures retried automatically).
- Zero rate-limit-induced incidents on shared Postgres in the first 60 days.

## User Stories
1. As a server owner, I generate a CSV of "daily active members for the last 30 days" and email it to a sponsor.
2. As a bot developer, I poll `/messages/timeseries` every 5 minutes and surface anomalies in my mod dashboard.
3. As a community manager, I export channel-level engagement and pivot it in a spreadsheet.
4. As an ops user, I revoke an API token from settings the moment a teammate leaves.

## Functional Requirements
- API tokens are issued from the server settings UI and are scoped to one server. They carry a role (`read`, `read:exports`) and a rate-limit tier.
- Endpoints: `GET /servers/{id}/metrics/summary`, `GET /messages/timeseries`, `GET /channels/engagement`, `GET /members/retention-cohorts`, `POST /exports`, `GET /exports/{job_id}`, `GET /exports/{job_id}/download`.
- Exports return a short-lived signed URL (Supabase storage) valid for 15 minutes.
- All responses include `X-RateLimit-Remaining`, `X-RateLimit-Reset`, and a server-scoped `X-Request-ID`.
- Timeseries support `granularity=hour|day|week` and a `from`/`to` window capped at 365 days.

## Constraints
- Must run on the existing Go monolith; no new service.
- Must reuse Supabase auth and RLS; tokens are stored hashed.
- Materialized views must refresh on a schedule that does not interfere with peak traffic windows.

## Risks
- Slow aggregations escaping the materialized view path could cascade into Postgres pressure. Mitigation: every endpoint has a hard query timeout and a fallback to "data not yet available" for cold cohorts.
- Token leakage. Mitigation: tokens are prefixed (`flk_an_`) so they are easy to scan for in repos, and rotating is one click.

## Open Questions
- Should we expose voice-channel metrics in v1 or wait until the voice telemetry pipeline stabilizes? Leaning toward v1.1.
- Pricing: free tier limits versus Pro tier limits are still being modeled.

## Release Plan
- Internal alpha behind a feature flag for two weeks, dogfooded by Flicko staff servers.
- Closed beta with 20 hand-picked servers for a month.
- Public GA with documentation portal and SDK examples in Go, TypeScript, and Python.
