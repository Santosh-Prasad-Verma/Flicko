/// Wire models for the authoritative Ludo engine.
///
/// These mirror the JSON emitted by the Go engine
/// (`backend/internal/services/game/ludo_engine.go` → `LudoGameState`,
/// `ludo_validator.go` → `Token` / `TurnState`). Field names below match the
/// Go struct tags exactly — `moveNum` is camelCase on the wire while the rest
/// are snake_case. That asymmetry is in the server struct; it is not a typo
/// here, so don't "fix" it without changing the Go tags too.
///
/// This is the *transport* shape. The playable board state lives in
/// `features/ludo/domain/ludo_state.dart`; these types are what the REST
/// endpoints return — used for initial load and for re-sync after a missed
/// realtime event.
library;

/// One Ludo token (piece).
class LudoToken {
  final int id;
  final String playerId;

  /// Board entry offset for this token's colour: 0, 13, 26 or 39.
  final int colorOffset;

  /// -1 = in base, 0-50 = perimeter, 51-56 = home run, 57 = finished.
  final int progressionIndex;

  const LudoToken({
    required this.id,
    required this.playerId,
    required this.colorOffset,
    required this.progressionIndex,
  });

  bool get isInBase => progressionIndex < 0;
  bool get isFinished => progressionIndex >= 57;

  factory LudoToken.fromJson(Map<String, dynamic> json) {
    return LudoToken(
      id: (json['id'] as num?)?.toInt() ?? 0,
      playerId: json['player_id'] as String? ?? '',
      colorOffset: (json['color_offset'] as num?)?.toInt() ?? 0,
      progressionIndex: (json['progression_index'] as num?)?.toInt() ?? -1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'player_id': playerId,
        'color_offset': colorOffset,
        'progression_index': progressionIndex,
      };
}

/// The dice roll for the current turn.
///
/// The server owns this: the roll is generated and stored server-side, and
/// [isConsumed] marks whether it has already been spent on a move. The client
/// cannot forge a dice value.
class LudoTurnState {
  final int diceValue;
  final String rollId;
  final bool isConsumed;

  const LudoTurnState({
    required this.diceValue,
    required this.rollId,
    required this.isConsumed,
  });

  factory LudoTurnState.fromJson(Map<String, dynamic> json) {
    return LudoTurnState(
      diceValue: (json['dice_value'] as num?)?.toInt() ?? 0,
      rollId: json['roll_id'] as String? ?? '',
      isConsumed: json['is_consumed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'dice_value': diceValue,
        'roll_id': rollId,
        'is_consumed': isConsumed,
      };
}

/// Authoritative server state for one Ludo game.
class LudoGameState {
  final String gameId;
  final List<String> players;
  final int activePlayerIndex;

  /// "active", "completed", etc. — set by the engine.
  final String status;
  final List<LudoToken> tokens;
  final LudoTurnState? turn;

  /// Monotonic sequence number. Clients compare this against the last realtime
  /// event they applied; a gap means events were missed and a full re-sync via
  /// `GameApiClient.getLudoState` is needed.
  final int moveNum;

  const LudoGameState({
    required this.gameId,
    required this.players,
    required this.activePlayerIndex,
    required this.status,
    required this.tokens,
    required this.turn,
    required this.moveNum,
  });

  bool get isCompleted => status == 'completed';

  /// The user id whose turn it is, or null when the index is out of range.
  String? get activePlayerId =>
      (activePlayerIndex >= 0 && activePlayerIndex < players.length)
          ? players[activePlayerIndex]
          : null;

  factory LudoGameState.fromJson(Map<String, dynamic> json) {
    return LudoGameState(
      gameId: json['game_id'] as String? ?? '',
      players: (json['players'] as List<dynamic>? ?? const [])
          .map((p) => p.toString())
          .toList(),
      activePlayerIndex: (json['active_player_index'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'unknown',
      tokens: (json['tokens'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LudoToken.fromJson)
          .toList(),
      turn: json['turn'] is Map<String, dynamic>
          ? LudoTurnState.fromJson(json['turn'] as Map<String, dynamic>)
          : null,
      moveNum: (json['moveNum'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'game_id': gameId,
        'players': players,
        'active_player_index': activePlayerIndex,
        'status': status,
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'turn': turn?.toJson(),
        'moveNum': moveNum,
      };
}

/// One row of the Ludo leaderboard (`GET /gaming/ludo/leaderboard`).
class LudoLeaderboardRow {
  final String userId;
  final String name;
  final int elo;
  final int wins;
  final int total;

  const LudoLeaderboardRow({
    required this.userId,
    required this.name,
    required this.elo,
    required this.wins,
    required this.total,
  });

  factory LudoLeaderboardRow.fromJson(Map<String, dynamic> json) {
    return LudoLeaderboardRow(
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Anonymous',
      elo: (json['elo'] as num?)?.toInt() ?? 1200,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
