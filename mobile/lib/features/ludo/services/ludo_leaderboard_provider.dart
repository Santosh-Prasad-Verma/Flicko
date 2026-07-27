import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../gaming/data/game_api_client.dart';
import '../../gaming/models/game_state.dart';
import '../../gaming/providers/gaming_stats_provider.dart';

/// One row of the Ludo leaderboard.
///
/// Alias of the shared wire model so the gaming and ludo features agree on a
/// single shape — the parsing lives in [LudoLeaderboardRow].
typedef LudoLeaderboardEntry = LudoLeaderboardRow;

/// Fetches the current top-50 Ludo players from
/// `GET /api/v1/gaming/ludo/leaderboard`.
///
/// Errors propagate deliberately. This provider used to fall back to a
/// hardcoded list of players (NayanX, KingDice, …) whenever the request failed,
/// which made an unreachable backend look like a populated leaderboard. The
/// screen already renders a "Failed to load leaderboard" state, so surfacing
/// the failure is both honest and actionable.
final ludoLeaderboardProvider =
    FutureProvider.autoDispose<List<LudoLeaderboardEntry>>((ref) async {
  return ref.watch(gameApiProvider).getLudoLeaderboard();
});

/// Submits a finished Ludo match to the backend.
///
/// Best-effort by design: the client is authoritative for the local result and
/// has already shown the winner, so a failed upload must not block or rewind
/// the UX. Failures are logged rather than silently dropped.
///
/// Takes [api] rather than a `Ref` so the caller owns provider access and this
/// stays directly testable.
/// [duration] is how long the match actually ran, measured by the board
/// screen. It used to be assumed: every finished match added a flat 15 minutes
/// to total playtime regardless of whether it lasted two minutes or an hour.
Future<void> submitLudoScore({
  required GameApiClient api,
  required String winnerId,
  required List<String> loserIds,
  required bool isBotGame,
  required Duration duration,
  String? gameId,
  String? currentUserId,
}) async {
  // Local stat counters first — these must land even if the network call
  // fails, since the stats screen reads them straight from prefs.
  if (currentUserId != null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final played = prefs.getInt(LudoStatKeys.matchesPlayed) ?? 0;
      await prefs.setInt(LudoStatKeys.matchesPlayed, played + 1);

      if (winnerId == currentUserId) {
        final won = prefs.getInt(LudoStatKeys.matchesWon) ?? 0;
        await prefs.setInt(LudoStatKeys.matchesWon, won + 1);
      }

      final minutes = prefs.getInt(LudoStatKeys.minutesPlayed) ?? 0;
      await prefs.setInt(
        LudoStatKeys.minutesPlayed,
        minutes + duration.inMinutes.clamp(0, 24 * 60),
      );

      // Stamp the match date so the stats heatmap has something to plot. Only
      // the retention window is kept, so this list stays bounded.
      final today = DateTime.now();
      final stamp = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final cutoff = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: LudoStatKeys.heatmapDays));
      final dates = <String>[
        ...(prefs.getStringList(LudoStatKeys.matchDates) ?? const [])
            .where((d) {
          final parsed = DateTime.tryParse(d);
          return parsed != null && parsed.isAfter(cutoff);
        }),
        stamp,
      ];
      await prefs.setStringList(LudoStatKeys.matchDates, dates);
    } catch (e) {
      developer.log('Failed to persist local ludo stats: $e', name: 'Ludo');
    }
  }

  try {
    await api.submitScore(
      gameId: gameId ?? '',
      winnerId: winnerId,
      loserIds: loserIds,
      isBotGame: isBotGame,
    );
  } catch (e) {
    developer.log('Ludo score upload failed (result kept locally): $e',
        name: 'Ludo');
  }
}
