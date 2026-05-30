# IMPL: Plugin System

## Phases
- P0 (week 1-2): manifest schema + signature verifier + DB migration 240.
- P1 (week 3-5): plugin-gateway service with wasmtime-go, instance pool, fuel limits, hook RPC.
- P2 (week 6-7): install/uninstall API, capability JWT issuer, audit log, kill switch.
- P3 (week 8-9): mobile UI (server settings list, install sheet, detail).
- P4 (week 10-11): `plug` CLI scaffolding + dev loop.
- P5 (week 12): mobile WASM runtime via wasmer-flutter shim, parity smoke tests.
- P6 (week 13): GA hardening, load tests, 20 launch-partner plugins.

## Backend Tasks
- `backend/internal/plugins/manifest/parser.go` parse + validate YAML.
- `backend/internal/plugins/manifest/signer.go` Ed25519 sign/verify.
- `backend/internal/plugins/registry/handlers.go` REST endpoints for plugins, versions.
- `backend/internal/plugins/installs/handlers.go` install/uninstall/list.
- `backend/cmd/plugin-gateway/main.go` standalone process, NATS consumer.
- `backend/internal/plugins/runtime/engine.go` wasmtime engine, module cache (LRU 256).
- `backend/internal/plugins/runtime/pool.go` per-install instance pool, idle timeout 60 s.
- `backend/internal/plugins/runtime/limits.go` fuel + memory + wall-clock killer.
- `backend/internal/plugins/runtime/host.go` host functions: post_message, kv_get, kv_set, http_fetch.
- `backend/internal/plugins/auth/captoken.go` mint/verify capability JWTs.
- `backend/internal/plugins/audit/writer.go` partitioned insert with batching.
- `backend/db/migrations/240_plugins.sql` schema + RLS.
- `backend/internal/gaming/module.go` (existing) wire NATS bridge for `voice.event` if voice plugin scope.

## Mobile Tasks
- `mobile/lib/features/plugins/data/plugin_repository.dart` REST client.
- `mobile/lib/features/plugins/presentation/screens/plugins_list_screen.dart`.
- `mobile/lib/features/plugins/presentation/screens/plugin_detail_screen.dart`.
- `mobile/lib/features/plugins/presentation/widgets/install_sheet.dart`.
- `mobile/lib/features/plugins/providers/plugins_provider.dart` Riverpod.
- `mobile/lib/core/router/app_router.dart` routes `/server/:id/plugins` + `/plugins/:id`.
- `mobile/lib/features/plugins/runtime/wasm_host.dart` mobile wasmer bridge (P5).
- Add row entry in `mobile/lib/features/server_channels/.../server_settings_screen.dart`.

## CLI Tasks
- `tools/plug/cmd/new.go` scaffold from template (Rust + AssemblyScript options).
- `tools/plug/cmd/build.go` invoke `cargo build --target wasm32-wasi`.
- `tools/plug/cmd/sign.go` Ed25519 sign with key from `~/.flicko/plugins/key`.
- `tools/plug/cmd/publish.go` upload manifest + wasm.
- `tools/plug/cmd/dev.go` watch + hot reload against local gateway.
- `tools/plug/cmd/doctor.go` validate manifest, check wasm size, scope sanity.

## Test Plan
- Unit: manifest parser, signature verify, fuel accounting, JWT scope check, pool eviction LRU.
- Integration: install -> hook fires -> audit row written; uninstall -> instance evicted within 2 s; kill switch propagation.
- Load: 1 k installs, 50 hooks/s each, p95 under 35 ms; soak 24 h, no memory leak (pprof RSS flat).
- Chaos: panic in plugin, infinite loop, OOM allocator, malformed wasm; gateway stays up.
- Security: scope escalation attempt rejected, signature tamper detected, JWT replay blocked by nonce + 5 min TTL.
- Mobile: install on iOS + Android low-end (4 GB), 4 plugins resident, scroll perf 60 fps.

## Cost: $0
- Reuses existing Postgres, NATS, Supabase storage for wasm blobs (Storage free tier 1 GB).
- wasmtime-go and wasmer-flutter are OSS, no licensing cost.
- No new infra; plugin-gateway runs on existing Go backend host pool, scales horizontally.
- Audit log partitions retained 30 days by default to fit Supabase free tier; longer retention is opt-in per server.

## Rollout
- Feature flag `plugins.enabled` per server, default off.
- Internal dogfood week 1-2 GA -1, then opt-in beta, then default on.
- Public registry frozen behind `plugins.public_registry` flag until 20 launch partners pass review.

## Open Tickets
- FLK-PLG-101: manifest parser
- FLK-PLG-102: gateway scaffolding
- FLK-PLG-103: capability JWT
- FLK-PLG-104: install REST
- FLK-PLG-110: mobile UI
- FLK-PLG-120: plug CLI
- FLK-PLG-130: mobile runtime
