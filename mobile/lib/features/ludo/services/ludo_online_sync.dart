import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart' as centrifuge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/ludo_state.dart';
import '../domain/plot_data.dart';
import 'ludo_notifier.dart';

/// One Centrifugo client per session. Reuses the same WS endpoint pattern as
/// `chessGameProvider`. URL ultimately comes from app config.
final ludoCentrifugoClientProvider = Provider<centrifuge.Client>((ref) {
  final client = centrifuge.createClient(
    'ws://localhost:8000/connection/websocket',
  );
  client.connect();
  ref.onDispose(client.disconnect);
  return client;
});

/// Wire: subscribes the active board screen to `game:<gameId>` and applies
/// authoritative dice / move / winner events from the server back into the
/// local [LudoNotifier].
///
/// **Event vocabulary (engine):**
///
/// ```
/// {"type": "dice",   "moveNum": 7,  "playerIndex": 1, "value": 4, ...}
/// {"type": "move",   "moveNum": 8,  "playerIndex": 1, "tokenId": 5,
///  "from": -1, "to": 0,  "captured": [], ...}
/// {"type": "move",   "moveNum": 9,  "playerIndex": 1, "tokenId": 5,
///  "from": 4,  "to": 17, "captured": [{"playerIndex":2,"tokenId":9}], ...}
/// {"type": "winner", "moveNum": 42, "playerIndex": 1}
/// ```
///
/// We translate engine fields (`playerIndex`, `tokenId`, `progressionIndex`)
/// into the port's vocabulary (`playerNo`, `pieceId`, absolute board `pos`)
/// and drive the existing notifier methods so animation + SFX run as if the
/// remote player had tapped locally.
///
/// Gap detection: each event carries `moveNum`. If a received `moveNum`
/// skips ahead, we trigger a full state re-sync via [onResync] (planned;
/// currently logs only, deferred to v1.1 alongside the `/api/v1/gaming/ludo/state` endpoint).
class LudoOnlineSync {
  LudoOnlineSync({
    required this.ref,
    required this.gameId,
    required this.notifier,
  });

  final Ref ref;
  final String gameId;
  final LudoNotifier notifier;

  centrifuge.Subscription? _sub;
  StreamSubscription<centrifuge.PublicationEvent>? _events;
  int _localMoveNum = 0;

  Future<void> connect() async {
    final client = ref.read(ludoCentrifugoClientProvider);
    final channel = 'game:$gameId';
    _sub = client.newSubscription(channel);
    _events = _sub!.publication.listen(_onEvent);
    await _sub!.subscribe();
  }

  void _onEvent(centrifuge.PublicationEvent event) {
    Map<String, dynamic> data;
    try {
      data = json.decode(utf8.decode(event.data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = data['type'] as String?;
    final moveNum = (data['moveNum'] as num?)?.toInt() ?? 0;
    final playerIndex = (data['playerIndex'] as num?)?.toInt();
    if (type == null || playerIndex == null) return;

    // Gap detection: if the server is more than one event ahead, we missed
    // something. Fetch the authoritative snapshot from
    // GET /api/v1/gaming/ludo/state/<gameId> and replace local state.
    if (moveNum > _localMoveNum + 1) {
      _resync();
      return;
    }
    if (moveNum <= _localMoveNum) return; // duplicate / out-of-order
    _localMoveNum = moveNum;

    final state = notifier.currentState;
    final playerNo = playerIndex + 1;
    if (playerNo < 1 || playerNo > state.seats.length) return;

    // Only apply events whose actor is a remote seat. Local seats already
    // mutated state through the UI.
    final seat = state.seats[playerIndex];
    if (seat.kind != SeatKind.remote) return;

    switch (type) {
      case 'dice':
        final value = (data['value'] as num?)?.toInt();
        if (value != null) {
          notifier.rollDice(forced: value);
        }
        break;

      case 'move':
        final tokenId = (data['tokenId'] as num?)?.toInt();
        final from = (data['from'] as num?)?.toInt();
        final to = (data['to'] as num?)?.toInt();
        if (tokenId == null || from == null || to == null) return;

        final pieceId = _pieceIdFor(playerIndex, tokenId);

        if (from == -1) {
          // Release from pocket. Pocket → starting cell.
          notifier.releaseFromPocket(playerNo, pieceId);
        } else {
          // Forward move on board. Convert engine `to` (progressionIndex,
          // 0..57, player-relative) to the absolute board position the
          // notifier expects.
          final targetPos = _absolutePosFor(playerNo, to);
          notifier.handleForward(
            playerNo: playerNo,
            pieceId: pieceId,
            targetPos: targetPos,
          );
        }
        break;

      case 'winner':
        // Server-side winner event: forfeit / timeout / authoritative
        // confirmation. The local engine usually flips `winner` itself in
        // handleForward, but we apply unconditionally as a backstop.
        notifier.applyRemoteWinner(playerNo);
        break;
    }
  }

  /// Fetches the authoritative snapshot and replaces local state.
  /// Best-effort — failures leave the local state alone (the next event will
  /// re-trigger this on the next gap).
  Future<void> _resync() async {
    try {
      final uri = Uri.parse(
          'http://localhost:8080/api/v1/gaming/ludo/state/$gameId');
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200) return;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final snapshot = _snapshotFromEngineJson(data, notifier.currentState);
      _localMoveNum = (data['moveNum'] as num?)?.toInt() ?? _localMoveNum;
      notifier.applySnapshot(snapshot);
    } catch (_) {
      // Swallow: another event will retry the resync.
    }
  }

  /// Translates an engine `LudoGameState` JSON into the port's `LudoState`.
  /// Tokens (-1, 0..57) become per-player pieces with absolute board pos and
  /// travelCount. Active player index becomes `chancePlayer = idx + 1`.
  static LudoState _snapshotFromEngineJson(
      Map<String, dynamic> data, LudoState current) {
    final tokens = (data['tokens'] as List<dynamic>? ?? []);
    final players = <int, List<PlayerPiece>>{1: [], 2: [], 3: [], 4: []};
    final plotted = <PlottedPiece>[];

    for (final raw in tokens) {
      final t = raw as Map<String, dynamic>;
      final id = (t['ID'] as num?)?.toInt() ?? (t['id'] as num?)?.toInt() ?? 0;
      final progIdx = (t['ProgressionIndex'] as num?)?.toInt() ??
          (t['progression_index'] as num?)?.toInt() ??
          -1;
      final playerIndex = id ~/ 4;
      final slot = (id % 4) + 1;
      final letter = ['A', 'B', 'C', 'D'][playerIndex.clamp(0, 3)];
      final pieceId = '$letter$slot';

      int pos;
      int travelCount;
      if (progIdx == -1) {
        pos = 0;
        travelCount = 0;
      } else if (progIdx >= 57) {
        pos = victoryStart[playerIndex] + 4;
        travelCount = 57;
      } else {
        pos = LudoOnlineSync._absolutePosFor(playerIndex + 1, progIdx);
        travelCount = progIdx + 1;
        plotted.add(PlottedPiece(id: pieceId, pos: pos));
      }

      players[playerIndex + 1]!.add(
        PlayerPiece(id: pieceId, pos: pos, travelCount: travelCount),
      );
    }

    final activeIdx =
        (data['active_player_index'] as num?)?.toInt() ??
            (data['ActivePlayerIndex'] as num?)?.toInt() ??
            0;
    final status = data['status'] as String? ?? data['Status'] as String? ?? '';
    final winner = status == 'completed' ? activeIdx + 1 : null;

    // Pad missing player lists to 4 pieces in pocket so the state stays
    // well-formed if the engine reported only some seats.
    for (final p in players.entries) {
      while (p.value.length < 4) {
        final letter = ['A', 'B', 'C', 'D'][p.key - 1];
        p.value.add(PlayerPiece(
            id: '$letter${p.value.length + 1}', pos: 0, travelCount: 0));
      }
    }

    return current.copyWith(
      player1: players[1],
      player2: players[2],
      player3: players[3],
      player4: players[4],
      currentPosition: plotted,
      chancePlayer: activeIdx + 1,
      diceNo: 1,
      isDiceRolled: false,
      pileSelectionPlayer: -1,
      cellSelectionPlayer: -1,
      touchDiceBlock: false,
      winner: winner,
    );
  }

  /// Translate (playerIndex, tokenId) → "A1".."D4".
  ///
  /// The engine assigns tokenId = playerIndex*4 + j (0..15). We map the
  /// player letter and use (tokenId % 4) + 1 for the 1..4 slot id.
  static String _pieceIdFor(int playerIndex, int tokenId) {
    const letters = ['A', 'B', 'C', 'D'];
    final letter = letters[playerIndex.clamp(0, 3)];
    final slot = (tokenId % 4) + 1;
    return '$letter$slot';
  }

  /// Translate engine progressionIndex (0..57, player-relative) into the
  /// absolute board cell number used by the Flutter port:
  ///   * 0..51 → perimeter cell, with start offset and 52-wrap
  ///   * 52..56 → home stretch (victoryStart[idx] + offset)
  ///   * 57 → last home cell (rendered inside FourTriangle anyway)
  static int _absolutePosFor(int playerNo, int progIdx) {
    final pIdx = playerNo - 1;
    if (progIdx <= 51) {
      var abs = startingPoints[pIdx] + progIdx;
      if (abs > 52) abs -= 52;
      return abs;
    }
    if (progIdx <= 56) {
      return victoryStart[pIdx] + (progIdx - 52);
    }
    return victoryStart[pIdx] + 4;
  }

  Future<void> dispose() async {
    await _events?.cancel();
    await _sub?.unsubscribe();
  }
}

/// Per-game sync provider keyed by gameId. Disposed automatically when the
/// board screen is popped.
final ludoOnlineSyncProvider =
    Provider.autoDispose.family<LudoOnlineSync?, String?>((ref, gameId) {
  if (gameId == null || gameId.isEmpty) return null;
  final notifier = ref.read(ludoNotifierProvider.notifier);
  final sync = LudoOnlineSync(ref: ref, gameId: gameId, notifier: notifier);
  scheduleMicrotask(() => sync.connect());
  ref.onDispose(() => sync.dispose());
  return sync;
});
