# PRD: Visual Webhook Builder

## Problem
Webhooks are how Flicko servers integrate with the rest of their stack: GitHub deploys posting to #releases, payment notifications routing to #ops, GitLab pipeline failures alerting on-call. Today, building a webhook means hand-rolling a payload mapping in YAML and pasting it into a settings textarea. There is no test path, no signature verification helper, no replay on failure, and no template library. Server owners give up and use Zapier instead, which costs them money and adds latency.

## Goals
- Ship a visual, drag-and-drop builder for inbound and outbound webhooks. Users compose triggers, transformations, and destinations on a canvas.
- Provide a curated template library (GitHub, GitLab, Stripe, Sentry, custom HTTP) so common integrations are one click.
- Sign every outbound webhook with HMAC-SHA256 and verify inbound webhooks against per-source secrets.
- Persist failed deliveries to a replay queue so transient destination outages do not lose events.

## Non-Goals
- Full workflow automation (Zapier-style multi-step branching) is reserved for a future "automations" product.
- Inbound webhook execution that mutates server state beyond message posting is out of scope.
- A marketplace of community templates is on the roadmap but not part of v1.

## Target Users
- Server admins integrating dev tools (GitHub, Jira, Linear, Sentry, Datadog).
- Community managers piping form submissions or merch alerts into channels.
- Bot developers who want a visual debugger before falling back to code.

## Success Metrics
- 40 percent of new servers configure at least one webhook within 14 days of creation.
- Median time-to-first-webhook drops from 23 minutes to under 4.
- Replay queue recovery rate above 95 percent within 1 hour of destination recovery.
- Signature verification adoption: 100 percent of outbound webhooks signed by default.

## User Stories
1. As an admin, I drag the GitHub template onto the canvas, paste my repo URL, pick a channel, and webhook events post within 30 seconds.
2. As a developer, I trigger a test event with a sample payload and watch the transformation step render the resolved values inline.
3. As an ops user, I see that yesterday's Stripe webhook to my billing channel failed twice; I click Replay All and the queue drains.
4. As a security-minded admin, I rotate the signing secret for an outbound webhook and the receiving service immediately rejects the old one.

## Functional Requirements
- Canvas with three node types: Trigger (event source), Transform (JSONata or template), Destination (channel post or HTTP call).
- Validation: every node has typed inputs and outputs; the canvas refuses to save if a connection is type-incompatible.
- Test runner: paste or upload a sample payload, run through the pipeline, see each node's output in a side panel.
- Template library with one-click install for the top 10 sources.
- Signature verification: inbound webhooks check `X-Flicko-Signature` against the stored secret; outbound webhooks emit it.
- Replay queue: failed deliveries persist for 7 days; user can replay individually, in bulk, or set automatic retry policy.

## Constraints
- Reuse the existing Flicko design system; the canvas should feel native, not a third-party embed.
- Backend stays on the Go monolith; no new microservice.
- Inbound webhooks must terminate within 10 seconds; long-running transforms are rejected.

## Risks
- Canvas complexity creep. Mitigation: ship v1 with linear pipelines only; branching arrives later if data shows demand.
- HMAC secret leakage via shared screenshots. Mitigation: secrets are masked everywhere, copy-on-click only, never appear in URLs.
- Replay storms after a destination recovers. Mitigation: replay drains at a configurable rate with jitter.

## Open Questions
- Should we support OAuth-based outbound auth (rather than just bearer tokens) in v1? Leaning yes for GitHub and Stripe.
- Versioning of templates: when GitHub changes their event schema, do we auto-migrate or require user action? Probably notify-and-prompt.

## Release Plan
- Internal alpha for two weeks with the GitHub and Stripe templates.
- Closed beta with 30 servers focused on dev-tool integrations.
- GA with the full template library, replay UI, and a "what's new" tour.
