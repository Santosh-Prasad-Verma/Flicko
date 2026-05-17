import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/game_state.dart';

final gameApiProvider = Provider<GameApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return GameApiClient(dio);
});

class GameApiClient {
  final Dio _dio;

  GameApiClient(this._dio);

  Future<GameState> getGameState(String gameId) async {
    final response = await _dio.get('/api/games/$gameId/state');
    final data = response.data;
    return GameState(
      fen: data['fen'] as String,
      moveNum: data['moveNum'] as int,
    );
  }

  Future<void> submitMove(String gameId, String moveStr) async {
    await _dio.post('/api/games/$gameId/move', data: {
      'move': moveStr,
    });
  }
}
