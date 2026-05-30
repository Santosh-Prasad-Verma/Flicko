# APPFLOW: Plugin System

## Install Flow (Mermaid)
```mermaid
sequenceDiagram
    participant U as User (admin)
    participant App as Mobile App
    participant API as Flicko API
    participant Reg as plugin-registry
    participant GW as plugin-gateway
    participant DB as Postgres
    U->>App: tap Install on Welcomer
    App->>API: POST /servers/:sid/plugins/welcomer/install
    API->>Reg: fetch latest manifest + signature
    Reg-->>API: manifest, wasm_url, sig
    API->>API: verify signature + scopes
    API->>DB: insert plugin_installs row
    API->>GW: WarmInstance(plugin_id, version)
    GW->>Reg: download module (cached)
    GW->>GW: compile + cache, run main_init
    GW-->>API: ready
    API-->>App: 201 install_id
    App->>U: show running state
```

## Hook Invocation Flow
```mermaid
sequenceDiagram
    participant Bus as NATS
    participant GW as plugin-gateway
    participant Inst as wasm instance
    participant Host as host fns
    Bus->>GW: message.created event
    GW->>GW: lookup installs subscribed to hook
    loop for each install
        GW->>GW: mint capability JWT (5min)
        GW->>Inst: call hook(payload, cap_token)
        Inst->>Host: post_message(cap_token, channel, body)
        Host->>Host: validate JWT, scope, rate-limit
        Host-->>Inst: ok
        Inst-->>GW: return
        GW->>DB: append audit row
    end
```

## State Machine: Plugin Install
```
              install
   [absent] ----------> [installing]
                           |
                           | manifest_ok + warm_ok
                           v
   [degraded] <-- error -- [active] -- toggle off --> [disabled]
       |                     ^                            |
       | retry success       |  toggle on                  |
       +---------------------+                            |
                                                          |
                        uninstall (any state) -> [absent]
```
Transitions:
- installing -> active: warm succeeds.
- active -> degraded: 3 consecutive crashes within 60 s, or fuel exceeded 10 times in 5 min.
- degraded -> active: exponential backoff probe succeeds.
- any -> absent: uninstall request from owner or admin kill switch on whole plugin id.

## Edge Cases
- Manifest changes scopes on update: install pinned to old version, owner sees banner "Welcomer 1.5.0 wants new permissions. Review."
- Network drop during install: install row stays in `installing` for max 60 s, then GC reaper marks `failed`, client retries idempotently with `Idempotency-Key`.
- Plugin publisher revoked: gateway flips disabled flag, all instances evicted within 2 s, server admins get push notification.
- Mobile app offline: hooks queue server-side; mobile UI shows last-synced timestamp, no local invocation.
- Two admins toggle simultaneously: optimistic lock via `updated_at`, second write returns 409, UI refetches.
- Plugin emits 100 messages: rate limiter (10/s) drops excess, audit row marks `rate_limited=true`, no crash.

## Developer Loop
```mermaid
sequenceDiagram
    participant Dev
    participant CLI as plug CLI
    participant Local as local gateway
    Dev->>CLI: plug new welcomer
    CLI->>Dev: scaffold (manifest, src/lib.rs)
    Dev->>CLI: plug dev
    CLI->>Local: load --watch
    Dev->>Dev: edit code, save
    CLI->>Local: hot reload
    Local-->>CLI: ok, attached to test server
```
