# UIUX: Zapier and Make Integration

## Surfaces
Two surfaces: Flicko Server Settings → Integrations tab, and the partner-side experience inside Zapier and Make.

## Server Settings Integrations Tab
Path in admin web: `Server → Settings → Integrations`.

### Layout
- Header card with the integration logo set: Zapier badge, Make badge, plus "Browse all" link.
- "Connected Apps" list showing each OAuth client with this server scope. Columns: app icon, name, granted scopes, last used, status pill.
- "Active Zaps" list pulling from `zap_triggers` view: zap title, trigger event, target host (favicon plus domain), tasks last 7 days, status (live, paused, errored).
- Right rail with delivery health: success rate gauge, p95 latency, dead-letter count.

### Visual Tokens
- Table rows: 56px height, alternating background `#16181D` / `#1A1D24`.
- Status pills: Live `#22C55E`, Paused `#F59E0B`, Errored `#EF4444`, Setup `#6B7280`.
- Icons sourced from partner brand assets (Zapier orange, Make purple).
- Card radius 16px. Inter 13/15.

### Empty State
"No integrations yet. Connect your tools through Zapier or Make to automate Flicko workflows." Two large CTA buttons: "Connect Zapier" and "Connect Make". Below, four template cards with one-line descriptions.

### Connection Detail Drawer
Click a connected app, drawer opens from right.
- App brand strip at top.
- "Granted scopes" chip list with tooltip explaining each.
- "Servers granted" list with revoke button per server.
- "Recent activity" feed: last 50 deliveries with timestamp, event type, target URL host, response code.
- "Revoke access" destructive button at the bottom, requires typed confirmation.

## OAuth Consent Screen
Hosted at `auth.flicko.app/oauth/authorize`. Mirrors Stripe Connect aesthetic: centered card, partner logo, scope checklist with explanations.

- "Zapier wants to connect to your Flicko"
- Server picker (multi-select among servers where the user has `integrations.manage`).
- Scope list rendered as labeled rows with plain language ("Send messages on your behalf", "Read your members list").
- "Authorize" primary button, "Cancel" ghost button. Bottom microcopy: "You can revoke this connection any time in Settings → Integrations."

## Webhook Health Dashboard
Path: `Settings → Integrations → Health`.
- Headline KPIs: Tasks today, Success rate, p95 delivery, Dead letters.
- Time series chart 24h with success vs failure split.
- Table of failing subscriptions sortable by failure count.
- Click a row to open the delivery log: request body, response code, response body, retry count, next retry ETA.

## Microcopy
- Errors: "We tried 5 times to deliver this event but the target returned 5xx. Will retry until tomorrow at 14:30."
- Pause action: "Pause this Zap on Flicko side. Zapier will keep your zap visible but stop receiving events."
- Loop detection notice: "We paused this subscription because it received 64 identical events in 60 seconds. Check your filters."

## Partner-side UX (Zapier example)
Inside zapier.com:
- App listing card with Flicko logo, tagline "Automate your community", category Communication.
- Trigger selection screen lists 10 triggers, each with a one-line description and example payload.
- Channel and role pickers render as searchable dropdowns powered by our search endpoints.
- Sample data shown after first connection, fetched from `/api/v1/zap/triggers/:type/sample`.

## Make UX
Make uses a node-style scenario editor. Our app shows up under "Other apps". Same triggers and actions, but module icons follow Make's hexagon shape and color rules.

## Mobile
Read-only health summary in the existing mobile Settings → Integrations screen. No editing on mobile in v1; CTA opens the web admin in browser.

## Accessibility
- All status pills double up text and color (pill says "Live").
- Webhook health charts have a tabular toggle for screen readers.
- Drawer dismiss via Esc.
