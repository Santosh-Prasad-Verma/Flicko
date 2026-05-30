import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ludo_state.dart';
import '../domain/plot_data.dart';
import 'ludo_sound_service.dart';

/// Notifier owning the entire Ludo game lifecycle.
/// Mirrors gameSlice + gameActions thunks from the RN port.
///
/// All async piece-by-piece animation steps run via [Future.delayed] like the
/// original; a single in-flight thunk is enforced through [touchDiceBlock].
class LudoNotifier extends Notifier<LudoState> {
  LudoNotifier({LudoSoundService? sound, Random? rng})
      : _sound = sound ?? LudoSoundService.instance,
        _rng = rng ?? Random();

  final LudoSoundService _sound;
  final Random _rng;

  void Function(int playerNo)? _onBotTurn;

  /// Optional bot-move callback. The board screen wires this up so we can
  /// drive auto-rolls + auto-picks without coupling the engine to UI timers.
  void Function(int playerNo)? get onBotTurn => _onBotTurn;
  set onBotTurn(void Function(int playerNo)? value) {
    _onBotTurn = value;
    if (value != null) {
      _maybeTriggerBot();
    }
  }

  @override
  LudoState build() => LudoState.initial();

  /// Exposes the current state for collaborators (bot brain, sync layer).
  /// `Notifier.state` is protected, so callers go through this getter.
  LudoState get currentState => state;

  // ────────────────────────────────────────────────────────────────────────
  // Reset / configuration
  // ────────────────────────────────────────────────────────────────────────

  void resetGame({
    LudoMode? mode,
    List<SeatConfig>? seats,
    String? gameId,
  }) {
    state = LudoState.initial(
      mode: mode ?? state.mode,
      seats: seats ?? state.seats,
      gameId: gameId ?? state.gameId,
    );
    _maybeTriggerBot();
  }

  void configure({
    required LudoMode mode,
    required List<SeatConfig> seats,
    String? gameId,
  }) {
    state = LudoState.initial(mode: mode, seats: seats, gameId: gameId);
    _maybeTriggerBot();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Reducers (1:1 with gameSlice.ts)
  // ────────────────────────────────────────────────────────────────────────

  void _updateDiceNumber(int diceNo) {
    state = state.copyWith(diceNo: diceNo, isDiceRolled: false);
  }

  void _enablePileSelection(int playerNo) {
    state = state.copyWith(
      touchDiceBlock: true,
      pileSelectionPlayer: playerNo,
    );
  }

  void _enableCellSelection(int playerNo) {
    state = state.copyWith(
      touchDiceBlock: true,
      cellSelectionPlayer: playerNo,
    );
  }

  void _disableTouch() {
    state = state.copyWith(
      touchDiceBlock: true,
      pileSelectionPlayer: -1,
      cellSelectionPlayer: -1,
    );
  }

  void _unfreezeDice() {
    state = state.copyWith(touchDiceBlock: false, isDiceRolled: false);
  }

  void _setFireworks(bool value) {
    state = state.copyWith(fireworks: value);
  }

  void clearFireworks() => _setFireworks(false);

  /// Externally-triggered winner (forfeit, timeout, or authoritative server
  /// notification). Bypasses the normal handleForward win check.
  void applyRemoteWinner(int playerNo) {
    if (state.winner != null) return;
    _announceWinner(playerNo);
    _sound.play('cheer');
  }

  /// Replace the entire game state. Used by the online sync layer when it
  /// detects a `moveNum` gap and refetches the authoritative snapshot.
  /// `seats`, `mode`, and `gameId` are preserved from the current local
  /// configuration since the server snapshot doesn't carry the seat layout.
  void applySnapshot(LudoState snapshot) {
    state = snapshot.copyWith(
      seats: state.seats,
      mode: state.mode,
      gameId: state.gameId,
    );
  }

  void _announceWinner(int? winner) {
    state = state.copyWith(winner: winner);
  }

  void _updatePlayerChance(int chancePlayer) {
    state = state.copyWith(
      chancePlayer: chancePlayer,
      touchDiceBlock: false,
      isDiceRolled: false,
    );
    _maybeTriggerBot();
  }

  void _updatePiece({
    required int playerNo,
    required String pieceId,
    required int pos,
    required int travelCount,
  }) {
    final updated = state.piecesFor(playerNo).map((p) {
      if (p.id != pieceId) return p;
      return p.copyWith(pos: pos, travelCount: travelCount);
    }).toList();

    final cur = List<PlottedPiece>.from(state.currentPosition);
    final idx = cur.indexWhere((e) => e.id == pieceId);
    if (pos == 0) {
      if (idx != -1) cur.removeAt(idx);
    } else {
      final entry = PlottedPiece(id: pieceId, pos: pos);
      if (idx != -1) {
        cur[idx] = entry;
      } else {
        cur.add(entry);
      }
    }

    state = state.copyWith(
      player1: playerNo == 1 ? updated : null,
      player2: playerNo == 2 ? updated : null,
      player3: playerNo == 3 ? updated : null,
      player4: playerNo == 4 ? updated : null,
      currentPosition: cur,
      pileSelectionPlayer: -1,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Public actions
  // ────────────────────────────────────────────────────────────────────────

  /// Roll dice for the current player. Mirrors Dice.handleDicePress with the
  /// same auto-pass logic when no piece can move.
  ///
  /// [forced] lets the caller specify the value (used by long-press → 6 in
  /// dev/testing, and by online sync from the authoritative server).
  Future<void> rollDice({int? forced}) async {
    if (state.touchDiceBlock || state.isDiceRolled || state.winner != null) {
      return;
    }
    final playerNo = state.chancePlayer;
    final diceNumber = forced ?? (_rng.nextInt(6) + 1);

    state = state.copyWith(isDiceRolled: true, touchDiceBlock: true);
    await _sound.play('dice_roll');
    await _delay(800);
    _updateDiceNumber(diceNumber);

    final pieces = state.piecesFor(playerNo);
    final isAnyPieceAlive =
        pieces.any((e) => e.pos != 0 && e.pos != travelToHome);
    final isAnyPieceLocked = pieces.any((e) => e.pos != 0);

    if (!isAnyPieceAlive) {
      if (diceNumber == 6) {
        _enablePileSelection(playerNo);
      } else {
        await _delay(600);
        _updatePlayerChance(_nextPlayer(playerNo));
      }
      return;
    }

    final canMove = pieces.any(
      (p) => p.travelCount + diceNumber <= travelToHome && p.pos != 0,
    );

    if ((!canMove && diceNumber == 6 && !isAnyPieceLocked) ||
        (!canMove && diceNumber != 6)) {
      await _delay(600);
      _updatePlayerChance(_nextPlayer(playerNo));
      return;
    }

    if (diceNumber == 6) _enablePileSelection(playerNo);
    _enableCellSelection(playerNo);
  }

  /// Releases a piece from the pocket onto its starting cell.
  void releaseFromPocket(int playerNo, String pieceId) {
    if (state.pileSelectionPlayer != playerNo) return;
    _updatePiece(
      playerNo: playerNo,
      pieceId: pieceId,
      pos: startingPoints[playerNo - 1],
      travelCount: 1,
    );
    _unfreezeDice();
  }

  /// Move a piece on the board by the current dice number, step-by-step.
  ///
  /// Returns once animation/SFX/capture has completed.
  Future<void> handleForward({
    required int playerNo,
    required String pieceId,
    required int targetPos,
  }) async {
    if (state.cellSelectionPlayer != playerNo) return;

    final diceNo = state.diceNo;
    _disableTouch();

    int finalPath = targetPos;
    final beforePiece =
        state.piecesFor(playerNo).firstWhere((e) => e.id == pieceId);
    int travelCount = beforePiece.travelCount;

    for (int i = 0; i < diceNo; i++) {
      final piece =
          state.piecesFor(playerNo).firstWhere((e) => e.id == pieceId);
      int path = piece.pos + 1;
      if (path == turningPoints[playerNo - 1]) {
        path = victoryStart[playerNo - 1];
      }
      if (path == 53) path = 1;

      finalPath = path;
      travelCount += 1;
      _updatePiece(
        playerNo: playerNo,
        pieceId: pieceId,
        pos: path,
        travelCount: travelCount,
      );
      await _sound.play('pile_move');
      await _delay(200);
    }

    final atFinal =
        state.currentPosition.where((e) => e.pos == finalPath).toList();
    final ids = atFinal.map((e) => e.id[0]).toSet();
    final differentOwners = ids.length > 1;

    if (safeSpots.contains(finalPath) || starSpots.contains(finalPath)) {
      await _sound.play('safe_spot');
    }

    if (differentOwners &&
        !safeSpots.contains(finalPath) &&
        !starSpots.contains(finalPath)) {
      final enemy = atFinal.firstWhere((p) => p.id[0] != pieceId[0]);
      await _capture(enemy);
      _unfreezeDice();
    }

    if (diceNo == 6 || travelCount == travelToHome) {
      if (travelCount == travelToHome) {
        await _sound.play('home_win');
        if (_hasTeamWon(playerNo) || _hasSoloWon(playerNo)) {
          _announceWinner(playerNo);
          await _sound.play('cheer');
          return;
        }
        _setFireworks(true);
        _unfreezeDice();
        _updatePlayerChance(playerNo);
        return;
      }
      _updatePlayerChance(playerNo);
    } else {
      _updatePlayerChance(_nextPlayer(playerNo));
    }
  }

  Future<void> _capture(PlottedPiece enemy) async {
    final no = switch (enemy.id[0]) {
      'A' => 1,
      'B' => 2,
      'C' => 3,
      _ => 4,
    };
    final backwardPath = startingPoints[no - 1];
    int i = enemy.pos;
    await _sound.play('collide');

    while (i != backwardPath) {
      _updatePiece(
        playerNo: no,
        pieceId: enemy.id,
        pos: i,
        travelCount: 0,
      );
      await _delay(40);
      i--;
      if (i == 0) i = 52;
    }
    _updatePiece(
      playerNo: no,
      pieceId: enemy.id,
      pos: 0,
      travelCount: 0,
    );
  }

  bool _hasSoloWon(int playerNo) {
    final pieces = state.piecesFor(playerNo);
    return pieces.every((p) => p.travelCount >= travelToHome);
  }

  /// In team mode (`SeatConfig.team` set on every seat), a team wins when
  /// both teammates have all 4 pieces home. This is the strict variant
  /// (rather than "any teammate finishes" which trivialises the second
  /// player). The seat that just placed its last piece is the trigger.
  bool _hasTeamWon(int triggeringPlayerNo) {
    final myTeam = state.seats[triggeringPlayerNo - 1].team;
    if (myTeam == null) return false;
    for (var i = 0; i < state.seats.length; i++) {
      final seat = state.seats[i];
      if (seat.team != myTeam) continue;
      final pieces = state.piecesFor(i + 1);
      if (!pieces.every((p) => p.travelCount >= travelToHome)) return false;
    }
    return true;
  }

  int _nextPlayer(int p) {
    final activeSeats = state.seats.length;
    int n = p + 1;
    if (n > activeSeats) n = 1;
    return n;
  }

  /// Notifier owning the entire Ludo game lifecycle.
  /// Mirrors gameSlice + gameActions thunks from the RN port.
  ///
  /// All async piece-by-piece animation steps run via [Future.delayed] like the
  /// original; a single in-flight thunk is enforced through [touchDiceBlock].
  ///
  /// When [reducedMotion] is true (set by the board screen from
  /// MediaQuery.disableAnimationsOf), per-cell + dice-roll delays are skipped
  /// so screen-reader users complete moves instantly.

  bool reducedMotion = false;

  Future<void> _delay(int ms) {
    if (reducedMotion) return Future<void>.value();
    return Future<void>.delayed(Duration(milliseconds: ms));
  }

  void _maybeTriggerBot() {
    if (state.winner != null) return;
    final seat = state.seats[state.chancePlayer - 1];
    if (seat.kind == SeatKind.bot && onBotTurn != null) {
      // Yield to the next microtask so callers see the new state first.
      Future<void>.microtask(() => onBotTurn!(state.chancePlayer));
    }
  }
}

final ludoNotifierProvider =
    NotifierProvider<LudoNotifier, LudoState>(LudoNotifier.new);
