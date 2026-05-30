import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// One row of the Ludo leaderboard returned by GET /api/v1/gaming/ludo/leaderboard.
class LudoLeaderboardEntry {
  final String userId;
  final String name;
  final int elo;
  final int wins;
  final int total;

  const LudoLeaderboardEntry({
    required this.userId,
    required this.name,
    required this.elo,
    required this.wins,
    required this.total,
  });

  factory LudoLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LudoLeaderboardEntry(
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Anonymous',
      elo: (json['elo'] as num?)?.toInt() ?? 1200,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Public API base URL used during development. Wire to the real
/// AuthInterceptor + dio instance once exposed.
const String _baseUrl = 'http://localhost:8080';

/// Fetches the current top-50 Ludo players. Falls back to a small mock list
/// when the backend is unreachable so the UI is always presentable.
final ludoLeaderboardProvider =
    FutureProvider.autoDispose<List<LudoLeaderboardEntry>>((ref) async {
  try {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/v1/gaming/ludo/leaderboard'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final list = (data['entries'] as List<dynamic>? ?? [])
          .map((e) =>
              LudoLeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return list;
    }
  } catch (_) {
    // Fall through to fallback.
  }
  return const [
    LudoLeaderboardEntry(
        userId: '1', name: 'NayanX', elo: 1842, wins: 124, total: 198),
    LudoLeaderboardEntry(
        userId: '2', name: 'KingDice', elo: 1731, wins: 98, total: 188),
    LudoLeaderboardEntry(
        userId: '3', name: 'Valkyrie', elo: 1683, wins: 82, total: 161),
    LudoLeaderboardEntry(
        userId: '4', name: 'StarLord', elo: 1612, wins: 71, total: 156),
    LudoLeaderboardEntry(
        userId: '5', name: 'Aurora', elo: 1577, wins: 65, total: 144),
  ];
});

/// Submits a finished Ludo match to the backend. Best-effort: errors are
/// swallowed so the local UX is never blocked.
Future<void> submitLudoScore({
  required String winnerId,
  required List<String> loserIds,
  required bool isBotGame,
  String? gameId,
}) async {
  try {
    await http
        .post(
          Uri.parse('$_baseUrl/api/v1/gaming/ludo/score'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'game_id': gameId ?? '',
            'winner_id': winnerId,
            'loser_ids': loserIds,
            'is_bot_game': isBotGame,
            'reason': 'home_win',
          }),
        )
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    // ignore — score is local-authoritative
  }
}
