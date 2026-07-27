import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Keys used to persist locally-measured Ludo stats.
///
/// Written by `submitLudoScore` when a match finishes. These are the only
/// gaming numbers this app actually measures, so they are the only ones the
/// stats dashboard reports.
class LudoStatKeys {
  const LudoStatKeys._();

  static const matchesPlayed = 'ludo_stat_matches_played';
  static const matchesWon = 'ludo_stat_matches_won';
  static const minutesPlayed = 'ludo_stat_minutes_played';

  /// `yyyy-MM-dd` for each finished match, one entry per match, pruned to the
  /// last [heatmapDays] days. Backs the activity heatmap.
  static const matchDates = 'ludo_stat_match_dates';

  /// Days the heatmap covers (10 columns x 6 rows on screen).
  static const heatmapDays = 60;
}

/// Gaming statistics for the stats dashboard.
class GamingStats {
  final String totalHours;
  final String trend;
  final List<TopGame> topGames;
  final List<Campaign> recentCampaigns;
  final List<int> activityHeatmap;
  final int ludoPlayed;
  final int ludoWon;
  final int ludoMinutes;

  const GamingStats({
    required this.totalHours,
    required this.trend,
    required this.topGames,
    required this.recentCampaigns,
    required this.activityHeatmap,
    required this.ludoPlayed,
    required this.ludoWon,
    required this.ludoMinutes,
  });

  /// Win rate as a 0..1 fraction; 0 when nothing has been played.
  double get winRateFraction =>
      ludoPlayed > 0 ? (ludoWon / ludoPlayed).clamp(0.0, 1.0) : 0.0;

  /// Parses the shape returned by `GET /api/v1/gaming/stats`.
  ///
  /// Kept for the day that endpoint reports measured values. It is deliberately
  /// **not** wired up yet: `stats_handler.go` derives `total_hours` from
  /// `12340 + games*2.5`, hardcodes `trend` to `"+18%"`, and returns a fixed
  /// three-item `recent_campaigns` list. It also counts a `games` table that
  /// does not exist in the live database, so the count falls back to 0 and the
  /// endpoint would report 12,340 hours to a user who has played nothing.
  factory GamingStats.fromJson(Map<String, dynamic> json) {
    return GamingStats(
      totalHours: json['total_hours'] as String? ?? '0h',
      trend: json['trend'] as String? ?? '+0%',
      topGames: (json['top_games'] as List<dynamic>?)
              ?.map((e) => TopGame.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recentCampaigns: (json['recent_campaigns'] as List<dynamic>?)
              ?.map((e) => Campaign.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      activityHeatmap: (json['activity_heatmap'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          List.filled(LudoStatKeys.heatmapDays, 0),
      ludoPlayed: json['ludo_played'] as int? ?? 0,
      ludoWon: json['ludo_won'] as int? ?? 0,
      ludoMinutes: json['ludo_minutes'] as int? ?? 0,
    );
  }

  /// An all-zero record, used when there is no signed-in user, prefs are
  /// unreadable, or no match has been played. Lists are empty rather than
  /// seeded with example games — the screen renders nothing for an empty list,
  /// which reads correctly as "no data yet".
  factory GamingStats.empty() => GamingStats(
        totalHours: '0h',
        trend: '+0%',
        topGames: const [],
        recentCampaigns: const [],
        activityHeatmap: List.filled(LudoStatKeys.heatmapDays, 0),
        ludoPlayed: 0,
        ludoWon: 0,
        ludoMinutes: 0,
      );
}

class TopGame {
  final String name;
  final String hours;
  final String color;

  /// Share of total playtime, 0..1. Drives the progress bar on the stats
  /// screen, which used to guess by string-matching [hours] for `'0.0'` and
  /// rendering the bar 85% full for anything else.
  final double share;

  const TopGame({
    required this.name,
    required this.hours,
    required this.color,
    this.share = 0,
  });

  factory TopGame.fromJson(Map<String, dynamic> json) => TopGame(
        name: json['name'] as String? ?? '',
        hours: json['hours'] as String? ?? '0h',
        color: json['color'] as String? ?? '#FFFFFF',
        share: ((json['share'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      );
}

class Campaign {
  final String name;
  final int progress;
  final String cover;

  const Campaign({
    required this.name,
    required this.progress,
    required this.cover,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
        name: json['name'] as String? ?? '',
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        cover: json['cover'] as String? ?? '',
      );
}

/// Gaming stats compiled from locally-recorded Ludo results.
///
/// Every value here is something the app actually measured when a match ended.
/// Three sources of invented data were removed:
///
///   * Channel-message and DM row counts were multiplied by 0.015 and added to
///     "total playtime", and their timestamps were what filled the activity
///     heatmap. Sending a message is not playing a game, so the gaming
///     dashboard was really rendering chat activity.
///   * A "Cyber Arena" entry always showing `0.0h` and a "Ludo Championship"
///     campaign whose progress was set to the Ludo win rate. Neither exists in
///     the app.
///   * The fallback record seeded those same two entries, so an unauthenticated
///     or failed load looked like a populated dashboard.
///
/// Ludo is the only game with a scoreboard, so it is the only game reported.
final gamingStatsProvider = FutureProvider<GamingStats>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return GamingStats.empty();

  final int played;
  final int won;
  final int minutes;
  final List<String> matchDates;

  try {
    final prefs = await SharedPreferences.getInstance();
    played = prefs.getInt(LudoStatKeys.matchesPlayed) ?? 0;
    won = prefs.getInt(LudoStatKeys.matchesWon) ?? 0;
    minutes = prefs.getInt(LudoStatKeys.minutesPlayed) ?? 0;
    matchDates = prefs.getStringList(LudoStatKeys.matchDates) ?? const [];
  } catch (_) {
    return GamingStats.empty();
  }

  if (played == 0) return GamingStats.empty();

  final hours = minutes / 60.0;
  final winRate = (won * 100) ~/ played;

  return GamingStats(
    totalHours: '${hours.toStringAsFixed(1)}h',
    trend: '+$winRate%',
    topGames: [
      TopGame(
        name: 'Ludo',
        hours: '${hours.toStringAsFixed(1)}h',
        color: '#52B788',
        // The only tracked game, so it accounts for all recorded playtime.
        share: hours > 0 ? 1.0 : 0.0,
      ),
    ],
    // No campaign system exists in the app; an empty list renders nothing.
    recentCampaigns: const [],
    activityHeatmap: heatmapFromMatchDates(matchDates),
    ludoPlayed: played,
    ludoWon: won,
    ludoMinutes: minutes,
  );
});

/// Buckets `yyyy-MM-dd` match dates into [LudoStatKeys.heatmapDays] cells of
/// intensity 0..3, oldest first, so the final cell is today.
List<int> heatmapFromMatchDates(List<String> dates) {
  final counts = List<int>.filled(LudoStatKeys.heatmapDays, 0);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final raw in dates) {
    final date = DateTime.tryParse(raw);
    if (date == null) continue;
    final daysAgo =
        today.difference(DateTime(date.year, date.month, date.day)).inDays;
    if (daysAgo < 0 || daysAgo >= LudoStatKeys.heatmapDays) continue;
    counts[LudoStatKeys.heatmapDays - 1 - daysAgo]++;
  }

  return counts.map((c) {
    if (c == 0) return 0;
    if (c <= 2) return 1;
    if (c <= 5) return 2;
    return 3;
  }).toList();
}
