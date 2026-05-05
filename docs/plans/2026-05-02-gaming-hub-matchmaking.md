# Gaming Hub — Matchmaking & Bot AI
> **Implementation Plan v4.0 — Master Architecture Edition**

**Stack:** Go · Flutter (Riverpod 3.0) · Supabase (PostgreSQL via `pgx`) · Redis (Lua) · Asynq (Tasks) · Stockfish · Centrifugo · Prometheus
**Phases:** 7 Phases · 20 Tasks (0–19)
**New in v4.0:** Integrated Master Algorithms (`pgx.CopyFrom` batching, Ludo 1D Modulo Arrays, Lua Token Buckets, Lock Heartbeats, Stockfish Pipe Draining, and Proxy Hydration).

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              Clients (Flutter Riverpod 3.0)             │
│        StreamNotifier + AsyncValue.guard() state        │
└────────────────────────┬────────────────────────────────┘
                         │ WebSocket (with Proxy Hooks)
┌────────────────────────▼────────────────────────────────┐
│                Centrifugo (WebSocket Layer)             │
│   Hydrates initial state via Proxy · History Recovery   │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP / gRPC
┌────────────────────────▼────────────────────────────────┐
│           Go Backend Pods (Stateless Workers)           │
│ Bounded Channels · Panic Recovery · Heartbeat Locks     │
└──────┬──────────────────────────┬───────────────────────┘
       │                          │
┌──────▼──────┐          ┌────────▼────────┐
│    Redis    │          │    Postgres     │
│  Lua ZSET   │          │  pgx.CopyFrom   │
│  Watchdogs  │          │  Read replicas  │
│  Asynq Jobs │          │  Partitioned    │
└─────────────┘          └─────────────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │   Chess Bot Microservice    │
                    │   Async Pipe Draining       │
                    └────────────────────────────┘
```

**Core principles:**
- Go backend pods are **fully stateless**.
- Advanced **Lua Scripts** ensure atomic execution for rate limits and match claims.
- **`pgx.CopyFrom`** is used for blazing-fast telemetry/state persistence.
- **Ludo logic** uses mathematical 1D array transformations ($O(1)$ constant time) instead of 2D coordinates.

### Gaming Hub Directory Structure
```text
Flicko/
│
├── 📱 mobile/                          # Flutter mobile application
│   └── lib/
│       └── features/gaming/            # Riverpod 3.0 gaming UI
│           ├── application/            # State logic & AsyncValue.guard handling
│           │   ├── chess_game_notifier.dart
│           │   └── ...
│           └── presentation/           # Optimistic UI & screens
│
├── 🔩 backend/                         # Go monolith — Gaming Hub Infrastructure
│   ├── cmd/server/
│   │   └── main.go                     # Hub wiring & graceful shutdown integration
│   │
│   ├── internal/
│   │   ├── gaming/
│   │   │   └── module.go               # Centralized DI & service orchestrator
│   │   │
│   │   ├── repo/
│   │   │   └── game_repo.go            # pgx.CopyFrom async batch persistence
│   │   │
│   │   ├── services/game/              # Core Hub business logic
│   │   │   ├── state_service.go        # Write-behind cache & version recovery
│   │   │   ├── chess_validator.go      # Move validation (notnil/chess wrapper)
│   │   │   ├── ludo_validator.go       # 1D array coordinate math & safe zones
│   │   │   ├── rng_service.go          # crypto/rand secure dice/rng
│   │   │   └── elo_service.go          # Zero-sum rating calculations
│   │   │
│   │   ├── bots/                       # AI and bot logic
│   │   │   ├── chess/
│   │   │   │   └── stockfish_pool.go   # Resilient os/exec Stockfish worker pool
│   │   │   └── coordinator.go          # Automates AI turn delays & execution
│   │   │
│   │   ├── handlers/
│   │   │   ├── game_handler.go         # REST API (e.g. /rejoin recovery)
│   │   │   └── centrifugo/
│   │   │       └── proxy.go            # Subscribe hooks & spectator validation
│   │   │
│   │   └── middleware/
│   │       └── rate_limiter.go         # Distributed Token Bucket Lua rate limits
│   │
│   └── migrations/
│       └── 070_gaming_hub_schema.up.sql # Games, states, & results pgx migrations
```

---

## Phase 0 — Foundational Infrastructure

---

### Task 0 — Authoritative Dice & RNG Service
**Risk:** Low
**Files:** `backend/internal/services/rng_service.go`

**Steps:**
1. Implement `DiceRoll(sides int) int` using `crypto/rand` for cryptographic fairness: `rand.Int(rand.Reader, big.NewInt(int64(sides)))`.
2. Emit `DICE_ROLLED` via Centrifugo with `{value, timestamp, serverSeed, moveNum}`.

---

### Task 1 — Data Layer: PostgreSQL (`pgx`) + Redis
**Risk:** High
**Files:** `backend/internal/repo/game_repo.go`, `backend/internal/repo/cache_repo.go`

**Database schema:**
*Games, Game States (Partitioned), Game Results. Users table extended with `elo INTEGER DEFAULT 1200`.*

**High-Throughput Persistence (`pgx.CopyFrom`):**
1. Do not use standard SQL `INSERT` for high-volume game states.
2. Push state payloads into a heavily buffered Go channel (e.g., capacity 100,000).
3. A background BatchWorker flushes the buffer to PostgreSQL natively using `db.CopyFrom` when either:
   - Size threshold reached (e.g., 500 records).
   - Time threshold reached (e.g., ticker fires every 500ms).

**Redis Cache & Distributed Locks:**
1. Implement **Expiring Lock with Auto-Renewal (Watchdog)**.
2. `AcquireLock` uses `SET lock_key uuid_token NX PX timeout`.
3. Launch a goroutine that ticks every `TTL/3`, extending the lock via a Lua `PEXPIRE` script if the UUID matches, preventing long-running tasks (like Stockfish) from losing their locks.
4. `ReleaseLock` uses an atomic Compare-and-Swap (CAS) Lua script (`GET` + `DEL`).

---

## Phase 1 — Real-time Infrastructure & Matchmaking

---

### Task 2 — Matchmaking Engine (Wait-Time Window Expansion)
**Risk:** ⚠️ High
**Files:** `backend/internal/services/matchmaking_lua.go`

**Steps:**
1. Queue players in Redis ZSET (`queue:{gameType}`) using ELO as the score.
2. **Mathematical Expansion**: Target range is calculated dynamically.
   $$ExpandedRange = BaseRange + (WaitSeconds \times ExpansionRate)$$
3. **Atomic Match Claiming**: Execute a unified Lua script that runs `ZRANGEBYSCORE` to find candidates, verifies counts, and instantly runs `ZREM` to remove them atomically, completely eliminating "stolen match" race conditions.

---

### Task 3 — WebSocket Layer: Centrifugo & Proxy Hydration
**Risk:** Medium
**Files:** `infra/centrifugo/config.json`, `backend/internal/services/centrifugo_publisher.go`

**Steps:**
1. Configure Centrifugo with Redis engine, `history_size: 50`, `history_ttl: "5m"`, and `recover: true`.
2. **Proxy Event Hooks**: Intercept `subscribe` events. Validate access.
3. **State Hydration**: Return the exact, current game state within the Centrifugo `info` or `data` response object. This completely removes the need for Flutter to make an HTTP `GET` request, eliminating race conditions between loading the UI and receiving the first WebSocket message.
4. **Abandonment**: Intercept `disconnect` hook to set an `abandonment:{gameId}:{userId}` key with 45s TTL.

---

## Phase 2 — Bot Generation & Simulation

---

### Task 4 & 6 — Matchmaking UI & Bot Profile Generator
**Steps:**
1. Flutter `matchmakingProvider` shows "Searching..." and awaits Centrifugo `subscribe` completion.
2. Generate mock users with realistic ELOs for bot fallback.

---

### Task 5 — Chess Bot Microservice (Safe UCI Pipe Management)
**Risk:** ⚠️ High
**Files:** `chess-bot-service/main.go`

**Steps:**
1. Wrap Stockfish via `os/exec`.
2. **Prevent OS Pipe Deadlocks**: Do not block on `stdout`. Immediately spawn a goroutine to continuously scan `cmd.StdoutPipe()`. If the Go app fails to drain standard out rapidly, the OS pipe fills, freezing the Stockfish process.
3. Send `position fen...` and `go movetime {ms}`.
4. Wait on a `resultChan` bounded by a `context.WithTimeout`.
5. Forcefully invoke `cmd.Process.Kill()` and `cmd.Wait()` on timeout/exit to release OS file descriptors.

---

### Task 7 & 8 — Ludo Bot & Asynq Coordinator
**Steps:**
1. Build Probabilistic Ludo Bot (priority scoring logic).
2. **Bot Turn Coordinator**: After a player moves against a bot, do not spawn an in-memory goroutine. Enqueue a delayed **Asynq** task (`TypeBotMove`). A dedicated worker picks it up. If the pod crashes, Asynq natively guarantees execution, preventing game stalls.

---

## Phase 3 — Server-Side Move Validation

---

### Task 9 — Chess Move Validator
**Risk:** Medium
**Files:** `backend/internal/services/chess_validator.go`

**Steps:**
1. Use the Watchdog UUID lock.
2. Validate via `notnil/chess`. Check conditions (Checkmate, Stalemate, 50-move rule).
3. Call `FinalizeGame()` on terminal states, compute new ELO via ELO service, publish `GAME_OVER`.

---

### Task 10 — Ludo Move Validator (1D Array Coordinate System)
**Risk:** ⚠️ High
**Files:** `backend/internal/services/ludo_validator.go`

**Steps:**
1. **Mathematics over Matrices**: Do not use 2D (X,Y) grids. Track each token purely as a `ProgressionIndex` (0 to 56).
2. Predefine entry offsets for the shared 52-square perimeter:
   - Red: 0, Green: 13, Yellow: 26, Blue: 39.
3. Calculate physical collisions in $O(1)$ time:
   $$PhysicalPosition = (EntryOffset + ProgressionIndex) \pmod{52}$$
4. **Safe Squares**: Maintain a bitmask of the 8 safe squares. If a collision occurs on a safe square, allow overlap. If unsafe, reset the enemy token's `ProgressionIndex` to -1 (yard).

---

### Task 11 — Game Timeout & Abandonment Enforcement
**Steps:**
1. Leader pod sweeps `TurnState.TurnExpiry` and `abandonment:{gameId}:{userId}` keys.
2. Forfeits timed-out/abandoned players.

---

## Phase 4 — Game Screens & Client Resilience

---

### Task 12 & 13 — Flutter Game Screens (Riverpod 3.0)
**Risk:** Low
**Files:** `mobile/lib/features/gaming/application/...`

**Steps:**
1. Utilize Riverpod 3.0 `StreamNotifier`.
2. **Optimistic Updates via `AsyncValue.guard`**:
   - Immediately mutate local UI state upon user action to mask network latency.
   - Wrap the Centrifugo `publishMove` call inside `AsyncValue.guard()`. If the backend rejects the move (e.g., collision math failed), the state automatically snaps back to the authoritative backend state, preventing crashes.
3. Use `select` aggressively to ensure high-frequency updates (like Stockfish evaluation bars) only rebuild a single widget, preserving 120 FPS and battery life.

---

## Phase 5 — Security & Resilience

---

### Task 14 — Reconnection & Session Recovery
**Steps:**
1. Handled entirely via Centrifugo's `history_size` and `recover: true`.
2. Re-hydrates state smoothly upon tunnel-exit/re-connection without slamming the Go database.

---

### Task 15 — Distributed Rate Limiting (Token Bucket Lua)
**Risk:** Medium
**Files:** `backend/internal/middleware/rate_limiter.go`

**Steps:**
1. Implement a true Token Bucket rate limiter at the ingress layer.
2. To prevent TOCTOU (Time-Of-Check to Time-Of-Use) race conditions, evaluation and token deduction must happen in a **single Redis Lua script**.
3. Include an `EXPIRE` command at the end of the script for the bucket key to prevent Memory Leaks from inactive clients.

---

## Phase 6 & 7 — Performance, Observability, Hardening

---

### Task 16, 17, 18, 19 — Async Writes, Tuning, Promethues
**Steps:**
1. Ensure the `pgx.CopyFrom` worker pool utilizes WaitGroups (`sync.WaitGroup`).
2. Intercept `SIGTERM` signals for Graceful Degradation, blocking shutdown until all pending telemetry and moves are flushed natively to PostgreSQL.
3. Add `/metrics` for `stockfish_timeouts`, `db_flush_latency`, and `rate_limit_hits`.

---

## Phase 8 — Centralized Module Orchestration

---

### Task 20 — Gaming Hub Initializer
**Risk:** Low
**Files:** `backend/internal/gaming/module.go`, `backend/cmd/server/main.go`

**Steps:**
1. **Unified Module Pattern**: Consolidate all discrete gaming services (State Service, Matchmaking, Validators, Bot Coordinators, and Proxy Handlers) into a single bounded context loader (`gaming.Initialize`).
2. **Dependency Injection**: Inject global singletons like the Redis client and PostgreSQL pool at the boundary level to decouple internal packages.
3. **Internal Interface Adapters**: Use local structural adapters (e.g., `hubGameAccessValidator`, `hubGameService`) to satisfy strict interface contracts between bounded contexts (e.g., passing the Chess Validator into the Bot Coordinator without cyclic dependencies).
4. **Graceful Shutdown Hook**: Expose a `hub.Shutdown()` method that explicitly drains the Stockfish os/exec worker pool and triggers the `StopAsyncWriter` on the `pgx.CopyFrom` batching system, ensuring zero dataloss or zombie processes during SIGTERM.

---

*Gaming Hub — Implementation Plan v4.0 | Master Architecture Edition*
