import 'dart:math';

import '../domain/ludo_state.dart';
import '../domain/plot_data.dart';
import 'ludo_notifier.dart';

/// Heuristic Ludo bot. Drives the engine when it's a bot's turn:
///   1. Roll the dice.
///   2. If a piece can be released (rolled a 6 + has pocket pieces), release.
///   3. Otherwise pick the best on-board piece using the configured
///      [BotDifficulty]:
///        * easy:   uniform random legal piece
///        * medium: capture > finish > safe > furthest
///        * hard:   medium + a penalty when the destination is reachable by
///                  any opponent piece on a 1..6 roll next turn.
class LudoBotBrain {
  LudoBotBrain(this.notifier, {Random? rng}) : _rng = rng ?? Random();

  final LudoNotifier notifier;
  final Random _rng;
  bool _busy = false;
  bool _isDisposed = false;

  void dispose() {
    _isDisposed = true;
  }

  Future<void> takeTurn(int playerNo) async {
    if (_busy || _isDisposed) return;
    _busy = true;
    try {
      final state = notifier.currentState;
      final difficulty = state.seats[playerNo - 1].difficulty;

      // small "thinking" pause; harder bots think a bit longer for feel.
      final baseThinkMs =
          switch (difficulty) { BotDifficulty.easy => 400, BotDifficulty.medium => 600, BotDifficulty.hard => 800 };
      await Future<void>.delayed(
          Duration(milliseconds: baseThinkMs + _rng.nextInt(400)));
      if (_isDisposed) return;

      await notifier.rollDice();
      if (_isDisposed) return;
      final stateAfterRoll = notifier.currentState;
      if (stateAfterRoll.winner != null) return;

      // Both release and move are possible (rolled a 6 + has pocket pieces + has on-board pieces)
      if (stateAfterRoll.pileSelectionPlayer == playerNo &&
          stateAfterRoll.cellSelectionPlayer == playerNo) {
        final onBoardPieces = stateAfterRoll
            .piecesFor(playerNo)
            .where((p) => p.pos != 0 && p.travelCount + 6 <= travelToHome)
            .toList();
        final hasPocket = stateAfterRoll.piecesFor(playerNo).any((p) => p.pos == 0);

        if (hasPocket && onBoardPieces.isNotEmpty) {
          final bestOnBoard = _pickPiece(onBoardPieces, 6, playerNo, stateAfterRoll, difficulty);
          final bestOnBoardScore = _score(playerNo, bestOnBoard, 6, stateAfterRoll, difficulty);

          // Releasing a piece has a base priority of 45. If the best on-board move is higher (e.g. capture/finish), do that!
          if (bestOnBoardScore > 45) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
            if (_isDisposed) return;
            final advanced = advancePiece(
              playerNo: playerNo,
              fromPos: bestOnBoard.pos,
              fromTravel: bestOnBoard.travelCount,
              diceNo: 6,
            );
            await notifier.handleForward(
              playerNo: playerNo,
              pieceId: bestOnBoard.id,
              targetPos: advanced.pos,
            );
            return;
          }
        }
      }

      // Pocket release path.
      if (stateAfterRoll.pileSelectionPlayer == playerNo) {
        final pocketPiece =
            stateAfterRoll.piecesFor(playerNo).firstWhere((p) => p.pos == 0);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (_isDisposed) return;
        notifier.releaseFromPocket(playerNo, pocketPiece.id);
        return;
      }

      // On-board move path.
      if (stateAfterRoll.cellSelectionPlayer == playerNo) {
        final dice = stateAfterRoll.diceNo;
        final pieces = stateAfterRoll
            .piecesFor(playerNo)
            .where((p) => p.pos != 0 && p.travelCount + dice <= travelToHome)
            .toList();
        if (pieces.isEmpty) return;

        final pick = _pickPiece(pieces, dice, playerNo, stateAfterRoll, difficulty);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (_isDisposed) return;

        final advanced = advancePiece(
          playerNo: playerNo,
          fromPos: pick.pos,
          fromTravel: pick.travelCount,
          diceNo: dice,
        );

        await notifier.handleForward(
          playerNo: playerNo,
          pieceId: pick.id,
          targetPos: advanced.pos,
        );
      }
    } finally {
      _busy = false;
    }
  }

  PlayerPiece _pickPiece(
    List<PlayerPiece> pieces,
    int dice,
    int playerNo,
    LudoState state,
    BotDifficulty difficulty,
  ) {
    if (difficulty == BotDifficulty.easy) {
      return pieces[_rng.nextInt(pieces.length)];
    }

    pieces.sort((a, b) =>
        _score(playerNo, b, dice, state, difficulty)
            .compareTo(_score(playerNo, a, dice, state, difficulty)));
    return pieces.first;
  }

  int _score(
    int playerNo,
    PlayerPiece piece,
    int dice,
    LudoState state,
    BotDifficulty difficulty,
  ) {
    final advanced = advancePiece(
      playerNo: playerNo,
      fromPos: piece.pos,
      fromTravel: piece.travelCount,
      diceNo: dice,
    );
    final target = advanced.pos;
    final travel = advanced.travelCount;

    var score = piece.travelCount;
    if (travel == travelToHome) score += 75;

    final occupants =
        state.currentPosition.where((p) => p.pos == target).toList();
    final enemies =
        occupants.where((p) => p.id[0] != piece.id[0]).toList();
    if (enemies.isNotEmpty &&
        !safeSpots.contains(target) &&
        !starSpots.contains(target)) {
      score += 100;
    }
    if (safeSpots.contains(target) || starSpots.contains(target)) {
      score += 25;
    }

    // Hard mode: penalise destinations that an opponent could capture from
    // their next move (any roll 1..6 that lands on `target` from a piece on
    // a non-safe perimeter cell).
    if (difficulty == BotDifficulty.hard &&
        !safeSpots.contains(target) &&
        !starSpots.contains(target) &&
        target <= 52) {
      final risky = _isReachableByOpponent(target, piece.id[0], state);
      if (risky) score -= 60;
    }

    return score;
  }

  /// Returns true if any opponent piece on the perimeter could reach
  /// [target] with a 1..6 roll. Cheap approximation: walks 1..6 cells back
  /// from `target` and checks if any opponent piece sits there.
  static bool _isReachableByOpponent(
      int target, String myLetter, LudoState state) {
    for (var d = 1; d <= 6; d++) {
      var src = target - d;
      if (src <= 0) src += 52;
      final hit = state.currentPosition
          .where((p) => p.pos == src && p.id[0] != myLetter);
      if (hit.isNotEmpty) return true;
    }
    return false;
  }
}
