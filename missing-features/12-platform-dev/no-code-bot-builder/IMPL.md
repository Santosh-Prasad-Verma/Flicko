# IMPL: No-Code Bot Builder

## Backend Layout
```
backend/internal/bots/
├── module.go              -- DI wiring
├── handler/
│   ├── bots.go            -- REST handlers
│   ├── runs.go
│   └── test.go
├── service/
│   ├── service.go
│   ├── validate.go        -- JSON Schema check
│   └── revisions.go
├── evaluator/
│   ├── engine.go          -- topo sort, run loop
│   ├── context.go
│   ├── interpolate.go     -- {{var.x}} expansion
│   └── limits.go
├── triggers/
│   ├── dispatcher.go
│   ├── index.go           -- in-memory index
│   ├── cron.go
│   └── nats_subscriber.go
├── actions/
│   ├── registry.go
│   ├── send_message.go
│   ├── send_dm.go
│   ├── add_role.go
│   ├── branch_if.go
│   ├── wait.go
│   └── ... (one file per action)
└── repository/
    ├── configs.go
    ├── runs.go
    └── logs.go
```

## Key Interfaces

```go
// Action is the unit of execution.
type Action interface {
    Type() string
    Schema() ParamSchema
    Execute(ctx context.Context, rc *RunContext, params Params) (Output, error)
}

// RunContext is shared state across nodes.
type RunContext struct {
    BotID      uuid.UUID
    ServerID   uuid.UUID
    Trigger    map[string]any
    Variables  *VarStore
    Logger     *zap.Logger
    DryRun     bool
    NodesUsed  int
    Deadline   time.Time
}
```

## Engine Loop (pseudo)

```go
func (e *Engine) Run(ctx context.Context, dsl *DSL, trig Trigger) (*RunResult, error) {
    rc := newRunContext(dsl, trig)
    ctx, cancel := context.WithDeadline(ctx, rc.Deadline)
    defer cancel()

    nodeID := dsl.EntryFor(trig.Type)
    for nodeID != "" {
        if rc.NodesUsed >= maxNodes { return rc.timeout("node_limit") }
        node := dsl.Node(nodeID)
        action := registry.Get(node.Type)
        params, err := e.interp.Resolve(node.Params, rc)
        if err != nil { return rc.fail(node, err) }

        out, err := action.Execute(ctx, rc, params)
        rc.LogNode(node, params, out, err)
        if err != nil { return rc.fail(node, err) }

        nodeID = dsl.NextEdge(nodeID, out.Branch)
        rc.NodesUsed++
    }
    return rc.success(), nil
}
```

## Frontend Layout
```
bot-builder/
├── src/
│   ├── App.tsx
│   ├── routes.tsx
│   ├── stores/
│   │   ├── botStore.ts        -- Zustand, holds DSL
│   │   └── undoMiddleware.ts
│   ├── components/
│   │   ├── Canvas.tsx         -- React Flow root
│   │   ├── NodePalette.tsx
│   │   ├── NodeInspector.tsx
│   │   ├── VariablesPanel.tsx
│   │   ├── RunLogsPanel.tsx
│   │   ├── TestPanel.tsx
│   │   └── nodes/
│   │       ├── TriggerNode.tsx
│   │       ├── ActionNode.tsx
│   │       └── BranchNode.tsx
│   ├── lib/
│   │   ├── api.ts
│   │   ├── dslTypes.ts
│   │   └── interpolation.ts
│   └── styles/tokens.css
├── public/
└── vite.config.ts
```

## Module Wiring
Update `backend/internal/gaming/module.go` style, register a new `bots.Module` in the main DI graph. Hook `triggers.Dispatcher` to start at boot and shutdown gracefully on context cancel.

## Tests
- Unit: `evaluator/engine_test.go` covers topo sort, branching, deadline, limits.
- Unit: `actions/*_test.go` per action with mocked Flicko clients.
- Integration: `bots_integration_test.go` spins up Postgres test container, NATS embedded server, triggers a member_joined event, asserts `bot_runs` row.
- E2E: Playwright suite in `bot-builder/e2e/` for create, save, enable, run flow.

## Rollout
1. Ship migration 243 behind feature flag `bot_builder_enabled`.
2. Internal dogfood for 1 week (Flicko team server only).
3. Closed beta: 20 servers via opt-in.
4. GA: flag default on for Pro tier, free tier capped at 2 bots.

## Telemetry to Watch
- p95 evaluator duration per node type.
- Drop rate on per-server queue.
- Save validation rejection rate (proxy for DSL editor bugs).
- Top 10 most used trigger and action types.

## Open Tickets at Ship
- Marketplace for community bots (post-launch).
- HTTP request action (deferred to Zapier integration).
- Multi-server bot publishing (post-launch).
- AI-suggested node next-step (post-launch).
