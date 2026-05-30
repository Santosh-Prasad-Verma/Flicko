# Notion / Linear Integration — UI/UX Design

## 1. Design Principles

- Admins-only surface; never expose tokens to non-admins
- Show provider logos faithfully; never colorize
- Status pills carry both Flicko and external label
- Backfill progress is visible and pause-able

## 2. Information Architecture

- Entry points:
  1. Server Settings -> Integrations
  2. Channel header overflow -> "Linked source" if a connector maps here
  3. Deep link `flicko://server/<sid>/integrations`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Integrations List | Connected and available | empty, content |
| 2 | Connector Detail | Manage tokens, mappings | content, loading, error |
| 3 | Mapping Editor | Pick filter and target | draft, validating, saving |
| 4 | Audit Log | Sync events | content, loading, empty |

## 4. Wireframes (ASCII)

### Integrations List

```
┌────────────────────────────────────────────────┐
│ Server Settings · Integrations                 │
├────────────────────────────────────────────────┤
│ Connected                                      │
│ ┌────────────────────────────────────────────┐ │
│ │ Linear   workspace: acme   3 mappings   ●  │ │
│ │ Last sync 2 min ago                        │ │
│ ├────────────────────────────────────────────┤ │
│ │ Notion   2 DBs   1 mapping             ●  │ │
│ │ Last sync 4 min ago                        │ │
│ └────────────────────────────────────────────┘ │
│ Available                                      │
│ ┌────────────────────────────────────────────┐ │
│ │ GitHub  [Coming soon]                      │ │
│ │ Jira    [Coming soon]                      │ │
│ └────────────────────────────────────────────┘ │
└────────────────────────────────────────────────┘
```

### Connector Detail

```
┌────────────────────────────────────────────────┐
│ ← Linear                                       │
├────────────────────────────────────────────────┤
│ Workspace: acme  ·  Token expires in 28 days   │
│ [ Reinstall ]  [ Pause ]  [ Disconnect ]       │
├────────────────────────────────────────────────┤
│ Mappings                                       │
│ ┌────────────────────────────────────────────┐ │
│ │ Team #api   ▶  #engineering                │ │
│ │ Filter: status != cancelled                │ │
│ │ Backfill: ✓ done · 312 items               │ │
│ │ [ Edit ]   [ Pause ]   [ Remove ]          │ │
│ ├────────────────────────────────────────────┤ │
│ │ Team #design ▶  #design-tasks              │ │
│ │ Filter: assignee=team   ⌛ syncing 67%     │ │
│ └────────────────────────────────────────────┘ │
│ [ + New mapping ]                              │
├────────────────────────────────────────────────┤
│ Recent activity                                │
│  ✓ APP-21 created -> #142  (1m ago)            │
│  ✓ APP-19 status -> done   (5m ago)            │
│  ⚠ APP-17 conflict (external wins)             │
└────────────────────────────────────────────────┘
```

### Mapping Editor

```
┌────────────────────────────────────────────────┐
│ ✕ New Linear mapping                Save       │
├────────────────────────────────────────────────┤
│ Source                                         │
│ Team       [ api ▾ ]                          │
│ Filter     [ status != cancelled ]            │
│                                                │
│ Target                                         │
│ Channel    [ #engineering ▾ ]                 │
│ Add to board [ Q3 Roadmap ▾ ] (optional)      │
│                                                │
│ Field mapping (advanced)                       │
│  Linear status -> Flicko status                │
│  ───────────────────────────────              │
│   Backlog        ->  todo                      │
│   In Progress    ->  in_progress              │
│   In Review      ->  in_progress              │
│   Done           ->  done                      │
│   Cancelled      ->  cancelled                │
│                                                │
│ Backfill window  [ 30 days ▾ ]                │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `ConnectorCard`
- Provider icon, status dot (green/yellow/red), last sync, mappings count

### `MappingRow`
- Source -> Target chips with arrow
- Backfill progress bar when active

## 6. Empty / Error / Loading

- Empty: provider tiles with "Install"
- Loading: shimmer rows
- Error: "Couldn't load connectors" inline

## 7. Copy

| Surface | Copy |
|---------|------|
| Install CTA | Install Linear |
| Reinstall CTA | Reinstall |
| Conflict warning | Conflicting change. We kept the {provider} version. |
| Backfill done | Backfill complete. Synced {n} items. |

## 8. Motion

- Status dot pulses when `syncing`
- Sync row slide-in 200ms

## 9. Accessibility

- Status dot paired with label text
- All admin actions screen-reader announced

## 10. Responsive

- Phone: stacked
- Tablet/web: 2-pane (list + detail)
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
- Provider brand colors only on logos
