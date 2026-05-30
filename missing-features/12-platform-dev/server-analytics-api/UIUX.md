# UIUX: Server Analytics API

## Surfaces
The analytics API has two human-facing surfaces inside Flicko: the token management screen in server settings, and the analytics dashboard that consumes the same endpoints under the hood. Everything else is developer-facing documentation.

## Token Management Screen
Path: Server Settings → Integrations → Analytics API.

Layout is a single column on mobile, two columns on desktop. The left column lists existing tokens; the right column holds the create-token panel. Each token row shows:
- A friendly name (set on creation, editable inline).
- The masked prefix (`flk_an_••••••••3a7f`) so users can identify tokens without exposing them.
- The role badge (`read` or `read:exports`).
- Last used timestamp, relative ("2 hours ago") with a tooltip showing the absolute UTC value.
- A kebab menu with Rotate, Revoke, View Usage.

Creating a token slides in a panel from the right with a single text input for the name, a role dropdown, and a tier selector. On submit, the full token is shown exactly once in a copy-on-click pill with a clear warning: "This is the only time you will see this token. Store it now." Clicking outside without copying surfaces a confirm dialog.

Revoke is destructive and confirmed via a typed-name guard ("type the token name to confirm"). Rotate generates a new value and invalidates the old one after a 24-hour grace window so deployments do not break instantly.

## Analytics Dashboard
The same endpoints back the in-app dashboard at Server Settings → Insights. The dashboard is intentionally simple in v1: a row of KPI cards (active members, messages per day, voice minutes, top channel), a 30-day timeseries chart, and a channel-engagement table.

KPI cards animate from a skeleton state on first load. Timeseries renders with smooth-line interpolation, no markers, and a subtle gradient fill so glances communicate trend more than precision. The channel table is sortable; clicking a column header re-fetches with the new sort to keep parity with API behavior.

An "Export" button in the top-right opens a modal: format (CSV or JSON), date range, granularity, and a single Generate button. Once submitted, the modal becomes a job-status panel that polls every 2 seconds. When ready, it surfaces a download button; the URL is fetched fresh on click so it is never stale.

## Empty States
- No data yet: a soft illustration of an empty bar chart with copy "Insights start showing up after your first 24 hours of activity."
- Token created but never used: the row shows "Never used" in muted text with a learn-more link to the docs portal.

## Error States
- Rate limited: a yellow banner ("You're sending requests too fast. Try again in 23 seconds.") that counts down.
- View stale: a small clock icon next to KPIs with a tooltip ("Data refreshed 6 hours ago, refresh in progress.").
- Export failed: the job row turns red with a Retry button and the failure reason.

## Microcopy
- Create button: "Generate token", not "Submit".
- Confirmation on revoke: "Revoke this token? Any tools using it will stop working immediately."
- Rate-limit header explanation in docs: "You'll see X-RateLimit-Remaining in every response. When it hits zero, you'll get a 429 with how long to wait."

## Accessibility
- All actions reachable by keyboard, with visible focus rings.
- Token reveal pill is announced by screen readers as "Sensitive value, double-tap to copy."
- Charts include a "View as table" toggle so the data is reachable without color or shape recognition.

## Responsive Behavior
- Mobile: KPI cards stack vertically, timeseries takes the full width with horizontal scroll, channel table collapses into a card list.
- Tablet: two-column KPI grid, full-width chart.
- Desktop: four-column KPI grid, two-column section for chart and table.

## Visual Tone
The dashboard uses Flicko's existing color tokens. Charts pick from the secondary accent palette (no neon greens) so they feel calm and analytical. Numbers use tabular figures to prevent jitter when values change.

## Documentation Portal
A separate static site at `developers.flicko.app/analytics` mirrors the design system: dark/light toggle, sticky sidebar of endpoints, code samples with a language switcher (Go, TS, Python, curl), and a live "Try it" panel that uses a sandbox token tied to a demo server.
