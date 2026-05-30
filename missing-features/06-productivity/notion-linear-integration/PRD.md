# Notion / Linear Integration — Product Requirements

> **One-line:** Two-way sync that turns Linear issues / Notion pages into Flicko tasks.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** XL
> **Priority:** P2

## 1. Problem

Many Flicko power-user servers (small teams, OSS projects, study groups) keep
their structured work in Linear or Notion and want to mirror it into chat. Today
they paste links by hand or run a Zapier flow that breaks weekly. Slack ships
official Linear and Notion apps; Discord has community-maintained bots that
half-work. Native, well-scoped two-way sync is a real differentiator.

## 2. Users & Use Cases

- **Primary persona:** small product team running on Linear; uses Flicko for
  community + day-to-day chat.
- **Secondary personas:** OSS maintainers tracking issues; Notion-native teams
  using docs as source of truth.
- **Top jobs-to-be-done:**
  1. As a PM, I want a Linear issue to appear as a Flicko task in #engineering
     and reflect status changes both ways.
  2. As a writer, I want a Notion database row to become a Flicko task that
     closes when the row's "Status" property says "Done".
  3. As an admin, I want explicit per-server connectors with scoped tokens.

## 3. Goals & Non-Goals

**Goals**
- OAuth install of Linear app and Notion integration per server
- Map filtered Linear views or Notion DB queries to a Flicko channel
- Two-way sync: status change on either side reflects on the other within 60s
- Backfill on connect (last 30 days)
- Handle webhooks from both providers; idempotent ingest
- Support multiple connectors per server

**Non-Goals (v1)**
- Sync of attachments, comments (links only)
- Editing rich-text body bidirectionally (one-way: external -> Flicko description, Flicko description -> external as plain text on update)
- Custom field mapping beyond status, assignee, due

## 4. Scope (v1)

- [ ] Linear OAuth + webhook subscription
- [ ] Notion OAuth + database polling (5 min) + page edit webhook
- [ ] Mapping config UI: pick Linear team/view -> Flicko channel
- [ ] Mapping config UI: pick Notion DB + filter -> Flicko channel
- [ ] Field mapping presets (sensible defaults)
- [ ] Status reconciliation rules (conflict policy: external wins)
- [ ] Audit log of every sync event
- [ ] Per-connector token rotation

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers with >=1 connector in 90d | 4% | events |
| Sync-success rate | >99.5% | telemetry |
| Median sync delay | <30s | telemetry |
| Cost per synced item/month | <$0.001 | infra |

## 6. Open Questions / Risks

- Conflict policy when both sides change at once. v1: external system wins;
  Flicko changes overwritten with warning.
- Rate limits: Linear allows 1500 req/h per workspace; Notion 3 req/s. We
  bucket per connector.
- Token leakage: store encrypted with KMS; rotate on schedule.
- Backfill volume can be large; cap initial sync to 30d, allow expand.
- Multiple connectors mapping to the same channel: fine; tasks tagged with
  source.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Slack Linear app | Mature, mature copy-paste UX | Native task object, not a card |
| Slack Notion | Limited two-way | Better Notion DB filter |
| Discord bots | Flaky | Native, scoped |

## 8. Rollout

- Internal dogfood 14d
- 20-server beta 28d
- Flag `feature.notion_linear_integration.enabled`
- 1% -> 10% -> 50% -> 100% over 28d
- Kill switch: revoke all webhooks; queue ingest paused
