import 'dart:convert';

/// Represents the state of a game (chess, ludo, etc.)
class GameState {
  final String fen;
  final int moveNum;

  GameState({required this.fen, required this.moveNum});

  GameState applyLocalMove(String move) {
    // Optimistic UI logic: applies move locally and bumps local sequence number
    return GameState(fen: fen, moveNum: moveNum + 1);
  }

  Map<String, dynamic> toJson() => {
        'fen': fen,
        'moveNum': moveNum,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      fen: json['fen'] as String,
      moveNum: json['moveNum'] as int,
    );
  }
}

/// Represents a game state update from the server.
class GameStateUpdate {
  final String type;
  final int moveNum;
  final GameState state;

  GameStateUpdate(this.type, this.moveNum, this.state);

  factory GameStateUpdate.fromJsonBytes(List<int> bytes) {
    final Map<String, dynamic> json = jsonDecode(utf8.decode(bytes));
    return GameStateUpdate(
      json['type'] as String,
      json['moveNum'] as int,
      GameState(fen: json['fen'] as String, moveNum: json['moveNum'] as int),
    );
  }
}
