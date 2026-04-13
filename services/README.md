# Flicko Services

Go monorepo containing the backend micro-services for Flicko.

```
services/
├── go.work              # Go workspace (links all modules)
├── Makefile             # Build / test / lint orchestration
├── shared/              # Foundation packages (config, logger, errors, id, validate, protocol)
├── ws-gateway/          # WebSocket Gateway — connection manager, Pub/Sub fanout
│   ├── cmd/gateway/     # Entrypoint (graceful shutdown, health, metrics)
│   └── internal/        # auth, conn, handler, pubsub, ratelimit, middleware
└── msg-service/         # Message Service — stateless REST API
    ├── cmd/server/      # Entrypoint (graceful shutdown, health, metrics)
    └── internal/        # auth, handler, service, repository, pubsub, idempotency, batcher, middleware
```

## Quick Start

```bash
# Run all tests
make test

# Build binaries → ../bin/
make build

# Vet + test + build
make
```

## Architecture

| Service | Port | Role |
|---|---|---|
| **ws-gateway** | `:8080` WS / `:9100` metrics | Stateful — holds WebSocket connections, authenticates via JWT+OpIdentify, rate-limits inbound frames, fans out via Redis Pub/Sub |
| **msg-service** | `:8081` HTTP / `:9101` metrics | Stateless — message/channel/guild CRUD, media presigned URLs, batch DB inserts |
| **shared** | library | Config, logger, errors, ULID IDs, input validation, wire protocol |

Both services import `shared/` as a local module via `go.work`.

See [Production-Architecture.md](../Documentation/Production-Architecture.md) for the full design.
