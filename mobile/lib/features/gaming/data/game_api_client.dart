import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/clients/dio_client.dart';
import '../models/game_state.dart';

/// REST client for the gaming hub.
///
/// Routes match what the Go backend actually registers in
/// `backend/internal/gaming/module.go` under its `/api/v1/gaming` subrouter:
///
/// ```
/// POST /gaming/ludo/roll   {game_id, player_id}            -> LudoGameState
/// POST /gaming/ludo/move   {game_id, player_id, token_id}  -> LudoGameState
/// GET  /gaming/ludo/state/{gameId}                         -> LudoGameState
/// POST /gaming/ludo/score  {game_id, winner_id, ...}
/// GET  /gaming/ludo/leaderboard                            -> {entries: [...]}
/// GET  /gaming/stats                                       -> stats payload
/// POST /gaming/rejoin      {game_id}
/// ```
///
/// Paths omit the `/api/v1` prefix on purpose: [dioProvider] already sets that
/// as its base URL and its interceptor strips a leading slash, so
/// `/gaming/stats` resolves to `<apiBaseUrl>/gaming/stats`. Spelling the prefix
/// out here would duplicate it.
final gameApiProvider = Provider<GameApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return GameApiClient(dio);
});

class GameApiClient {
  final Dio _dio;

  GameApiClient(this._dio);

  /// Fetches authoritative state for [gameId].
  ///
  /// Used on board entry, and to re-sync after a `moveNum` gap is detected in
  /// the realtime stream.
  Future<LudoGameState> getLudoState(String gameId) async {
    final response = await _dio.get('/gaming/ludo/state/$gameId');
    return LudoGameState.fromJson(_asMap(response.data));
  }

  /// Asks the server to roll the dice for [playerId].
  ///
  /// The roll is generated server-side — there is deliberately no way for a
  /// client to supply its own dice value.
  Future<LudoGameState> rollDice({
    required String gameId,
    required String playerId,
  }) async {
    final response = await _dio.post(
      '/gaming/ludo/roll',
      data: {'game_id': gameId, 'player_id': playerId},
    );
    return LudoGameState.fromJson(_asMap(response.data));
  }

  /// Moves [tokenId] using the current (unconsumed) dice roll.
  Future<LudoGameState> moveToken({
    required String gameId,
    required String playerId,
    required int tokenId,
  }) async {
    final response = await _dio.post(
      '/gaming/ludo/move',
      data: {
        'game_id': gameId,
        'player_id': playerId,
        'token_id': tokenId,
      },
    );
    return LudoGameState.fromJson(_asMap(response.data));
  }

  /// Reports a finished match so ELO and win counts are updated.
  Future<void> submitScore({
    required String winnerId,
    required List<String> loserIds,
    required bool isBotGame,
    String gameId = '',
    String reason = 'home_win',
  }) async {
    await _dio.post(
      '/gaming/ludo/score',
      data: {
        'game_id': gameId,
        'winner_id': winnerId,
        'loser_ids': loserIds,
        'is_bot_game': isBotGame,
        'reason': reason,
      },
    );
  }

  /// Top-50 Ludo players by ELO.
  Future<List<LudoLeaderboardRow>> getLudoLeaderboard() async {
    final response = await _dio.get('/gaming/ludo/leaderboard');
    final entries = _asMap(response.data)['entries'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(LudoLeaderboardRow.fromJson)
        .toList();
  }

  /// Aggregate gaming stats for the signed-in user.
  ///
  /// Returned as a raw map because the payload is presentation-shaped
  /// (pre-formatted hour strings, heatmap buckets) rather than a domain entity.
  Future<Map<String, dynamic>> getStats() async {
    final response = await _dio.get('/gaming/stats');
    return _asMap(response.data);
  }

  /// Rejoins an in-progress game after a disconnect.
  Future<Map<String, dynamic>> rejoin(String gameId) async {
    final response = await _dio.post(
      '/gaming/rejoin',
      data: {'game_id': gameId},
    );
    return _asMap(response.data);
  }

  /// Normalises a Dio response body to a map.
  ///
  /// Dio returns an already-decoded `Map` for JSON, but a `String` when the
  /// server omits or mislabels the content type. A clear [FormatException]
  /// here beats an opaque cast error at the call site.
  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw FormatException(
      'Expected a JSON object from the gaming API, got ${data.runtimeType}',
    );
  }
}
