# Ludo - Technical Requirements Document

**Status:** Draft v1
**Last updated:** 2026-05-29

## 1. Architecture

### 1.1 Mobile (Flutter)

```
mobile/lib/features/ludo/
  domain/
    plot_data.dart         # Board layout constants + advancePiece() helper
    ludo_state.dart        # Immutable LudoState, PlayerPiece, SeatConfig
  services/
    ludo_notifier.dart     # Riverpod 3 Notifier owning the game lifecycle
    ludo_sound_service.dart# audioplayers pool wrapper
    ludo_bot_brain.dart    # Heuristic AI; reuses advancePiece()
    ludo_leaderboard_provider.dart # FutureProvider + submitLudoScore()
  presentation/
    screens/
      ludo_home_screen.dart        # Mode picker
      ludo_board_screen.dart       # Main game screen
      ludo_matchmaking_screen.dart # Online lobby (currently stubbed)
      ludo_leaderboard_screen.dart # Top 50
    widgets/
      pile_widget.dart       # Token + rotating dashed selector
      cell_widget.dart       # Path cell (renders pieces, star, arrow, safe bg)
      pocket_widget.dart     # Corner pocket holding 4 in-base tokens
      path_widgets.dart      # Horizontal + Vertical paths
      four_triangle.dart     # Centre home, fireworks Lottie host
      dice_widget.dart       # Per-player dice + Lottie roll + arrow
      menu_modal.dart, winner_modal.dart, ludo_colors.dart
mobile/test/features/ludo/
  ludo_notifier_test.dart    # 9 engine unit tests
mobile/assets/ludo/
  animations/{diceroll,firework,trophy,girl,witch}.json
  images/{arrow,logo,menu,start,card-logo}.png
  images/dice/{1..6}.png
  images/piles/{red,green,yellow,blue}.png
  sfx/{cheer,collide,dice_roll,game_start,girl1..4,home,home_win,pile_move,safe_spot,ui}.mp3
```

### 1.2 Backend (Go)

```
backend/internal/handlers/game/
  ludo_handler.go        # Existing: roll + move endpoints
  ludo_score_handler.go  # NEW: POST /score, GET /leaderboard
  stats_handler.go       # Existing: aggregate stats
backend/internal/services/game/
  ludo_engine.go         # Existing: authoritative state machine
  ludo_validator.go      # Existing: move validation
backend/internal/gaming/
  module.go              # Wires all of the above into the Mux router
```

## 2. State management

The notifier mirrors the original RN Redux slice 1:1 to keep the port auditable. Each public method maps to either a reducer or a thunk in `react-native-ludo-game/src/redux/reducers/`:

| RN action | Flutter equivalent |
|---|---|
| `updateDiceNumber` | `_updateDiceNumber()` |
| `enablePileSelection` | `_enablePileSelection()` |
| `enableCellSelection` | `_enableCellSelection()` |
| `disableTouch` | `_disableTouch()` |
| `unfreezeDice` | `_unfreezeDice()` |
| `updateFireworks` | `_setFireworks()` |
| `announceWinner` | `_announceWinner()` |
| `updatePlayerChance` | `_updatePlayerChance()` |
| `updatePlayerPieceValue` | `_updatePiece()` |
| `handleForwardThunk` | `handleForward()` |

State exposure: `Notifier.state` is protected, so collaborators (bot brain, future sync layer) read through `currentState` getter. Mutations go through public action methods only - no external setter.

## 3. Networking

### 3.1 Endpoints (existing + new)

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/v1/gaming/ludo/roll` | Authoritative dice (existing) |
| POST | `/api/v1/gaming/ludo/move` | Authoritative move (existing) |
| POST | `/api/v1/gaming/ludo/score` | **NEW** Persist match result + ELO bump |
| GET | `/api/v1/gaming/ludo/leaderboard` | **NEW** Top 50 by ELO+wins |
| POST | `/api/v1/gaming/rejoin` | Existing: rejoin after reconnect |

### 3.2 Centrifugo channels

- `games/{game_id}` - server pushes `dice`, `move`, `capture`, `winner` events.
- Client subscribes via existing `centrifuge` package wiring (see `mobile/lib/features/...`).

### 3.3 Optimistic UX

- Local dice spin while POST `/roll` is in flight; if server returns a different value, replace and play a small "correction" SFX. Rollback path is documented but not yet implemented.

## 4. Data model

See `docs/ludo/BackendSchema.md`.

## 5. Dependencies

### 5.1 Flutter (added)

- `lottie ^3.1.2` - dice tumble, fireworks, trophy.
- `audioplayers ^6.1.0` - SFX + bgm.
- (existing) `flutter_riverpod ^3.3.1`, `go_router ^17.2.2`, `google_fonts ^8.0.2`.

### 5.2 Go

No new modules - reuses `pgx`, `gorilla/mux`, `zap`.

## 6. Build & run

```bash
# Mobile
cd mobile
flutter pub get
flutter run                       # device or emulator
flutter test                      # unit tests
flutter analyze lib/features/ludo

# Backend
cd backend
go build ./...
go test ./internal/services/game/...
go run ./cmd/server
```

## 7. Observability

- Sentry breadcrumbs at: `roll_dice`, `release_pocket`, `handle_forward_start`, `capture`, `winner_announced`. (To be wired - currently engine emits no telemetry.)
- Backend: `zap` structured logs already cover the score handler.

## 8. Performance budgets

| Operation | Budget |
|---|---|
| Cold-start to lobby | <= 1500 ms |
| Mode tap to board first paint | <= 800 ms |
| Per-cell move animation | 200 ms (engine `_delay`) |
| Dice roll animation | 800 ms |
| Online roll RTT (p95) | <= 250 ms |

## 9. Known gaps (deferred)

| ID | Item | Status |
|---|---|---|
| L-1 | Centrifugo subscribe in board screen | Stubbed in matchmaking screen |
| L-2 | Friends invite link generation + deep-link join | UI button exists, no logic |
| L-3 | Team mode scoring | Routes accept `team=true` param, no engine logic |
| L-4 | Authoritative roll/move sync | Local rolls only |
| L-5 | Audio asset compression | ~9 MB; target <2 MB |
| L-6 | Bot difficulty tiers | Single heuristic |
| L-7 | Spectator mode | Not designed |

## 10. Test plan

- **Unit:** `mobile/test/features/ludo/ludo_notifier_test.dart` covers advance math, pocket release, turn passing, dice-6 grants extra. 9 tests passing.
- **Integration:** TODO - full game loop with golden screenshots of board.
- **E2E:** TODO - on-device test via `flutter drive`.
- **Manual:** see `docs/ludo/ManualTestPlan.md` (TODO).
