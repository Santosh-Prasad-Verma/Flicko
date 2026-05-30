import 'package:flutter/foundation.dart';

/// A single token belonging to a player.
@immutable
class PlayerPiece {
  /// e.g. "A1" through "D4". First letter encodes the player.
  final String id;

  /// 0 = in pocket, 1..52 = perimeter, 111..445 = home stretches.
  final int pos;

  /// Number of cells travelled. 57 means it has reached the centre.
  final int travelCount;

  const PlayerPiece({
    required this.id,
    required this.pos,
    required this.travelCount,
  });

  PlayerPiece copyWith({int? pos, int? travelCount}) => PlayerPiece(
        id: id,
        pos: pos ?? this.pos,
        travelCount: travelCount ?? this.travelCount,
      );

  /// Owning player number (1..4).
  int get playerNo => switch (id[0]) {
        'A' => 1,
        'B' => 2,
        'C' => 3,
        _ => 4,
      };
}

/// Compact reference to a piece on the board (used by `currentPosition`).
@immutable
class PlottedPiece {
  final String id;
  final int pos;

  const PlottedPiece({required this.id, required this.pos});
}

/// What kind of agent controls each seat.
enum SeatKind { human, bot, remote }

/// Bot difficulty. Tunes the brain heuristic in [LudoBotBrain]:
///   * easy   — uniform random pick from legal moves
///   * medium — current heuristic (capture > finish > safe > furthest)
///   * hard   — same heuristic + opponent capture-risk lookahead penalty
enum BotDifficulty { easy, medium, hard }

/// Team affiliation for 2v2 mode. Standard pairing: red+yellow vs green+blue.
enum LudoTeam { a, b }

@immutable
class SeatConfig {
  final SeatKind kind;
  final String displayName;

  /// Optional remote user id when [kind] is [SeatKind.remote].
  final String? userId;

  /// Optional team for 2v2 mode. `null` for free-for-all matches.
  final LudoTeam? team;

  /// Difficulty for bot seats; ignored for human/remote seats. Defaults to
  /// medium so existing call sites continue to behave as before.
  final BotDifficulty difficulty;

  const SeatConfig({
    required this.kind,
    required this.displayName,
    this.userId,
    this.team,
    this.difficulty = BotDifficulty.medium,
  });

  static const empty = SeatConfig(
      kind: SeatKind.human,
      displayName: '—',
      userId: null,
      team: null);
}

/// Game-wide mode (how the lobby was launched).
enum LudoMode { localPass, vsBot, onlineRandom, onlineFriends }

/// Centralised, immutable game state. Mirrors the RN gameSlice 1:1.
@immutable
class LudoState {
  final List<PlayerPiece> player1;
  final List<PlayerPiece> player2;
  final List<PlayerPiece> player3;
  final List<PlayerPiece> player4;

  /// Player whose dice/piece-select is active (1..4).
  final int chancePlayer;

  /// Latest dice roll, 1..6.
  final int diceNo;

  /// True when the dice has rolled and the player is choosing a piece.
  final bool isDiceRolled;

  /// -1 means no pocket selection enabled, otherwise the player number.
  final int pileSelectionPlayer;

  /// -1 means no on-board cell selection enabled, otherwise the player number.
  final int cellSelectionPlayer;

  /// True while a move is animating; UI must ignore taps.
  final bool touchDiceBlock;

  /// All pieces currently on the board (excludes pocket and finished).
  final List<PlottedPiece> currentPosition;

  /// True briefly after a piece reaches home (for fireworks animation).
  final bool fireworks;

  /// 1..4 once a player has won, otherwise null.
  final int? winner;

  /// Per-seat configuration (index 0 = player 1, …).
  final List<SeatConfig> seats;

  final LudoMode mode;

  /// Optional online game id (Centrifugo channel suffix).
  final String? gameId;

  const LudoState({
    required this.player1,
    required this.player2,
    required this.player3,
    required this.player4,
    required this.chancePlayer,
    required this.diceNo,
    required this.isDiceRolled,
    required this.pileSelectionPlayer,
    required this.cellSelectionPlayer,
    required this.touchDiceBlock,
    required this.currentPosition,
    required this.fireworks,
    required this.winner,
    required this.seats,
    required this.mode,
    required this.gameId,
  });

  factory LudoState.initial({
    LudoMode mode = LudoMode.localPass,
    List<SeatConfig>? seats,
    String? gameId,
  }) {
    return LudoState(
      player1: const [
        PlayerPiece(id: 'A1', pos: 0, travelCount: 0),
        PlayerPiece(id: 'A2', pos: 0, travelCount: 0),
        PlayerPiece(id: 'A3', pos: 0, travelCount: 0),
        PlayerPiece(id: 'A4', pos: 0, travelCount: 0),
      ],
      player2: const [
        PlayerPiece(id: 'B1', pos: 0, travelCount: 0),
        PlayerPiece(id: 'B2', pos: 0, travelCount: 0),
        PlayerPiece(id: 'B3', pos: 0, travelCount: 0),
        PlayerPiece(id: 'B4', pos: 0, travelCount: 0),
      ],
      player3: const [
        PlayerPiece(id: 'C1', pos: 0, travelCount: 0),
        PlayerPiece(id: 'C2', pos: 0, travelCount: 0),
        PlayerPiece(id: 'C3', pos: 0, travelCount: 0),
        PlayerPiece(id: 'C4', pos: 0, travelCount: 0),
      ],
      player4: const [
        PlayerPiece(id: 'D1', pos: 0, travelCount: 0),
        PlayerPiece(id: 'D2', pos: 0, travelCount: 0),
        PlayerPiece(id: 'D3', pos: 0, travelCount: 0),
        PlayerPiece(id: 'D4', pos: 0, travelCount: 0),
      ],
      chancePlayer: 1,
      diceNo: 1,
      isDiceRolled: false,
      pileSelectionPlayer: -1,
      cellSelectionPlayer: -1,
      touchDiceBlock: false,
      currentPosition: const [],
      fireworks: false,
      winner: null,
      seats: seats ??
          const [
            SeatConfig(kind: SeatKind.human, displayName: 'You'),
            SeatConfig(kind: SeatKind.human, displayName: 'Player 2'),
            SeatConfig(kind: SeatKind.human, displayName: 'Player 3'),
            SeatConfig(kind: SeatKind.human, displayName: 'Player 4'),
          ],
      mode: mode,
      gameId: gameId,
    );
  }

  /// Returns the piece list for [playerNo] (1..4).
  List<PlayerPiece> piecesFor(int playerNo) => switch (playerNo) {
        1 => player1,
        2 => player2,
        3 => player3,
        _ => player4,
      };

  LudoState copyWith({
    List<PlayerPiece>? player1,
    List<PlayerPiece>? player2,
    List<PlayerPiece>? player3,
    List<PlayerPiece>? player4,
    int? chancePlayer,
    int? diceNo,
    bool? isDiceRolled,
    int? pileSelectionPlayer,
    int? cellSelectionPlayer,
    bool? touchDiceBlock,
    List<PlottedPiece>? currentPosition,
    bool? fireworks,
    Object? winner = _sentinel,
    List<SeatConfig>? seats,
    LudoMode? mode,
    String? gameId,
  }) {
    return LudoState(
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      player3: player3 ?? this.player3,
      player4: player4 ?? this.player4,
      chancePlayer: chancePlayer ?? this.chancePlayer,
      diceNo: diceNo ?? this.diceNo,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      pileSelectionPlayer: pileSelectionPlayer ?? this.pileSelectionPlayer,
      cellSelectionPlayer: cellSelectionPlayer ?? this.cellSelectionPlayer,
      touchDiceBlock: touchDiceBlock ?? this.touchDiceBlock,
      currentPosition: currentPosition ?? this.currentPosition,
      fireworks: fireworks ?? this.fireworks,
      winner: identical(winner, _sentinel) ? this.winner : winner as int?,
      seats: seats ?? this.seats,
      mode: mode ?? this.mode,
      gameId: gameId ?? this.gameId,
    );
  }

  static const _sentinel = Object();
}
