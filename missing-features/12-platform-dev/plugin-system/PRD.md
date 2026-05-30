# PRD: Plugin System

## Summary
A WASM-based plugin runtime that lets third-party developers extend Flicko (servers, mobile, desktop) without shipping native code. Plugins are sandboxed wasm modules with declared capabilities, signed manifests, and per-server installation. Server admins browse, install, configure, and disable plugins from a unified panel. Plugins can hook into messages, slash commands, voice events, and the AI assistant context.

## Problem
Flicko has grown into a chat + voice + gaming platform, but every integration today (welcome bots, role syncers, custom moderation) requires a backend code change. There is no safe way to let server owners install community-built behavior. Forking the app is painful and opens security holes. Competing platforms (Discord, Slack) win on the long tail of community automations we cannot ship internally.

## Jobs To Be Done
- As a server owner, I want to install a moderation plugin in two taps so my channel is protected without writing code.
- As a developer, I want to publish a plugin once and have it run identically on iOS, Android, web, and the Go backend.
- As a member, I want plugins to never read my DMs unless the manifest explicitly says so, and I want to see that capability before I join.
- As a platform operator, I want to kill any misbehaving plugin remotely without redeploying clients.
- As an AI assistant author, I want plugins to register tools so Aura can call them with user consent.

## In Scope
- WASM module loader (wasmtime-go) on backend; embedded mobile runtime via `wasmer-flutter` shim.
- Manifest YAML (name, version, scopes, hooks, resource caps).
- Capability token system: short-lived JWTs scoped to message:read, channel:write, voice:listen, etc.
- Plugin install/uninstall, per-server enable/disable, version pinning, auto-update channel (stable/beta).
- Hot reload, crash isolation, fuel-based execution limits (CPU + memory + wall clock).
- Developer CLI `flicko plug` for scaffold, build, sign, publish.
- Audit log of every capability invocation.

## Out of Scope
- Native (non-WASM) plugins.
- Paid plugins (handled by App & Theme Store feature).
- Cross-server shared plugin state (v2).
- UI-injecting plugins beyond declared slot widgets.
- Plugins that modify Flicko core protocol.

## Success Metrics
1. p95 plugin invocation latency under 35 ms server-side at 50 req/s per plugin.
2. 200 published plugins within 6 months of GA.
3. Crash-induced server downtime from plugins: 0 incidents per quarter (sandbox holds).
4. 60% of active servers have at least one plugin installed within 12 months.

## Competitive Landscape
| Platform | Sandbox | Mobile parity | Capability model | Pricing |
|---|---|---|---|---|
| Discord Apps | Hosted only, no sandbox | Limited (slash only) | Bot scopes | Free |
| Slack Apps | Hosted, OAuth | Yes | OAuth scopes | Free + paid |
| Mattermost | Go plugins, native | Backend only | None | OSS |
| Rocket.Chat | Apps Engine (Deno) | Partial | Permissions list | Free + paid |
| Flicko (this) | WASM, edge + mobile | Full parity | Cap tokens, signed manifest | Free, paid via Store |

## Risks
- WASM cold starts add latency; mitigate with module cache and pre-warmed instance pool.
- Mobile RAM pressure on low-end Android; cap per-plugin memory at 16 MB default, 64 MB max.
- Supply-chain attacks on community plugins; mandatory developer identity, signed releases, store review for capability escalations.

## Release Plan
- M1: backend runtime + manifest + capability token issuance.
- M2: install/uninstall API, audit log, kill switch.
- M3: developer CLI, scaffolding template, local dev loop.
- M4: mobile runtime (Flutter), hot reload.
- M5: GA with 20 launch-partner plugins.

## Open Questions
- Do we expose a JS-to-WASM compiler in the CLI to widen the developer pool, or hold the line on Go/Rust/AssemblyScript only.
- Should voice plugins receive raw PCM or only transcribed text by default.
