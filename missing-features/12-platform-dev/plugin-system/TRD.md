# TRD: Plugin System

## Architecture
```
+-----------------------------+        +-----------------------+
|  Mobile (Flutter)           |        |  Web / Desktop        |
|  +-----------------------+  |        |  +----------------+   |
|  | wasmer_flutter shim   |  |        |  | wasm-bindgen   |   |
|  +-----------+-----------+  |        |  +-------+--------+   |
+--------------|--------------+        +----------|------------+
               |  signed manifest + module bytes  |
               v                                  v
        +-------------------------------------------------+
        |  Plugin Gateway (Go service, separate process)   |
        |  - manifest validator                            |
        |  - capability token signer (RS256)               |
        |  - per-plugin instance pool (wasmtime-go)        |
        |  - fuel limiter / mem cap / wall-clock killer    |
        +----------------+--------+-----------------------+
                         |        |
            audit events |        | hook RPC (gRPC)
                         v        v
                 +-------------------+   +------------------+
                 | Postgres (RLS)    |   | NATS bus         |
                 | plugin_*, audit   |   | message.created  |
                 +-------------------+   | voice.event etc. |
                                         +------------------+
```

## Components
- `plugin-gateway` (Go): owns wasmtime engines, instance pool, fuel accounting.
- `plugin-registry` (Go service): manifests, versions, signatures, install records.
- `plugin-host-sdk` (Go + Rust): host functions (http_fetch, kv_get, post_message).
- `plug` CLI (Go): scaffold, build, sign, publish, doctor.

## REST Routes
- `POST /api/v1/plugins` register manifest (developer scope).
- `POST /api/v1/plugins/:id/versions` upload signed `.wasm`.
- `GET /api/v1/plugins/:id` public metadata.
- `POST /api/v1/servers/:sid/plugins/:id/install` install with version pin and config.
- `DELETE /api/v1/servers/:sid/plugins/:id` uninstall.
- `PATCH /api/v1/servers/:sid/plugins/:id` enable/disable, update config.
- `GET /api/v1/servers/:sid/plugins` list installed.
- `POST /api/v1/plugins/:id/kill` admin-only emergency stop, propagates via NATS.
- Internal gRPC: `Invoke(plugin_id, hook, payload, cap_token) -> response`.

## Capability Tokens
- RS256 JWT, kid rotated daily.
- Claims: `plugin_id`, `install_id`, `server_id`, `scopes[]`, `exp` (max 5 min), `nonce`.
- Issued on hook entry, validated by host functions.
- Scopes: `message:read`, `message:write`, `channel:list`, `voice:transcript`, `kv:rw`, `http:domain:<host>`.

## Manifest (YAML)
```
id: com.acme.welcomer
version: 1.4.2
runtime: wasm32-wasi
hooks: [member.joined, slash.welcome]
scopes: [message:write, kv:rw]
resources: { mem_mb: 16, fuel: 50000000, wall_ms: 200 }
http_allow: [api.acme.com]
ui_slots: [server_settings]
signature: sha256:...
```

## NFRs
- p95 invoke latency under 35 ms; p99 under 80 ms.
- Crash isolation: a panic inside a plugin instance never kills gateway worker.
- Memory cap enforced via wasmtime `ResourceLimiter`; fuel via `Store.set_fuel`.
- Cold start under 8 ms with module cache; under 60 ms uncached.
- Mobile: max 4 plugins resident, LRU evict on memory pressure.

## Observability
- Per-invoke trace span with plugin_id, hook, latency, fuel_used, mem_peak.
- Counter `plugin_invoke_total{result}`, histogram `plugin_invoke_seconds`.
- Audit log row per capability call (selectable retention 30/90 days).
- Sentry breadcrumbs scrubbed of plugin payload bodies.

## Security Review
- All wasm executed in non-shared linear memory, no SIMD threads.
- Host imports allow-listed; no `wasi:filesystem` exposed.
- Manifest signature verified with publisher Ed25519 key registered at developer signup.
- `http_fetch` egress proxied with per-domain allowlist and 256 KB body cap.
- Rate limit per install: 50 invocations/s burst, 10/s sustained.
- Kill switch: row update flips `plugin_versions.disabled = true`, gateway watches via Postgres LISTEN, evicts cached instances within 2 s globally.

## Failure Modes
- Fuel exhausted: return `PluginTimeout` to caller, increment counter, do not crash hook chain.
- Memory cap hit: instance terminated, install marked `degraded`, owner notified.
- Manifest mismatch on upgrade: install pinned to last good version.
