import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Model for Gaming Stats API response
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

  factory GamingStats.fromJson(Map<String, dynamic> json) {
    return GamingStats(
      totalHours: json['total_hours'] as String? ?? '0h',
      trend: json['trend'] as String? ?? '+0%',
      topGames: (json['top_games'] as List<dynamic>?)
              ?.map((e) => TopGame.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentCampaigns: (json['recent_campaigns'] as List<dynamic>?)
              ?.map((e) => Campaign.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      activityHeatmap: (json['activity_heatmap'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          List.filled(60, 0),
      ludoPlayed: json['ludo_played'] as int? ?? 0,
      ludoWon: json['ludo_won'] as int? ?? 0,
      ludoMinutes: json['ludo_minutes'] as int? ?? 0,
    );
  }

  /// Fallback static data used when the API is unreachable.
  factory GamingStats.fallback() => GamingStats(
        totalHours: '0h',
        trend: '+0%',
        topGames: const [
          TopGame(name: 'Ludo Royale', hours: '0h', color: '#52B788'),
          TopGame(name: 'Cyber Arena', hours: '0h', color: '#40916C'),
        ],
        recentCampaigns: const [
          Campaign(
              name: 'Ludo Championship',
              progress: 0,
              cover: '/gaming/armored_warrior.png'),
        ],
        activityHeatmap: List.filled(60, 0),
        ludoPlayed: 0,
        ludoWon: 0,
        ludoMinutes: 0,
      );
}

class TopGame {
  final String name;
  final String hours;
  final String color;

  const TopGame({
    required this.name,
    required this.hours,
    required this.color,
  });

  factory TopGame.fromJson(Map<String, dynamic> json) => TopGame(
        name: json['name'] as String? ?? '',
        hours: json['hours'] as String? ?? '0h',
        color: json['color'] as String? ?? '#FFFFFF',
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

/// Riverpod FutureProvider that compiles gaming stats from Supabase and SharedPreferences.
final gamingStatsProvider = FutureProvider<GamingStats>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return GamingStats.fallback();
  }

  int ludoPlayed = 0;
  int ludoWon = 0;
  int ludoMinutes = 0;
  int messagesSentCount = 0;
  int dmsSentCount = 0;
  List<int> heatmap = List.filled(60, 0);

  try {
    // 1. Fetch Ludo stats from local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    ludoPlayed = prefs.getInt('ludo_stat_matches_played') ?? 0;
    ludoWon = prefs.getInt('ludo_stat_matches_won') ?? 0;
    ludoMinutes = prefs.getInt('ludo_stat_minutes_played') ?? 0;

    // 2. Query channel messages and DMs counts from Supabase
    try {
      final msgRes = await client
          .from('messages')
          .select('id')
          .eq('author_id', userId);
      messagesSentCount = (msgRes as List).length;
    } catch (_) {}

    try {
      final dmRes = await client
          .from('direct_messages')
          .select('id')
          .eq('sender_id', userId);
      dmsSentCount = (dmRes as List).length;
    } catch (_) {}

    // 3. Query message timestamps of the last 60 days to build the heatmap
    final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
    List<String> timestamps = [];

    try {
      final msgTimestamps = await client
          .from('messages')
          .select('created_at')
          .eq('author_id', userId)
          .gt('created_at', sixtyDaysAgo.toIso8601String());
      for (var row in (msgTimestamps as List)) {
        if (row['created_at'] != null) {
          timestamps.add(row['created_at'].toString());
        }
      }
    } catch (_) {}

    try {
      final dmTimestamps = await client
          .from('direct_messages')
          .select('created_at')
          .eq('sender_id', userId)
          .gt('created_at', sixtyDaysAgo.toIso8601String());
      for (var row in (dmTimestamps as List)) {
        if (row['created_at'] != null) {
          timestamps.add(row['created_at'].toString());
        }
      }
    } catch (_) {}

    // Process heatmap counts
    final now = DateTime.now();
    final counts = List<int>.filled(60, 0);
    for (var ts in timestamps) {
      try {
        final date = DateTime.parse(ts);
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 60) {
          counts[59 - diff]++;
        }
      } catch (_) {}
    }

    // Map message counts to heatmap levels (0 to 3)
    heatmap = counts.map((count) {
      if (count == 0) return 0;
      if (count <= 2) return 1;
      if (count <= 5) return 2;
      return 3;
    }).toList();

  } catch (e) {
    // Gracefully handle SharedPreferences or other general exceptions
    return GamingStats.fallback();
  }

  // Calculate total hours: Ludo play time + conversation hours (approx 1 min / 0.016 hours per sent message)
  final double ludoHours = ludoMinutes / 60.0;
  final double chatHours = (messagesSentCount + dmsSentCount) * 0.015;
  final double totalHoursVal = ludoHours + chatHours;

  final String totalHoursStr = totalHoursVal > 0.0 
      ? '${totalHoursVal.toStringAsFixed(1)}h' 
      : '0h';

  // Trend: Win rate percentage of Ludo matches
  final int winRate = ludoPlayed > 0 ? ((ludoWon * 100) ~/ ludoPlayed) : 0;
  final String trendStr = '+$winRate%';

  // Top Games list (without Chess)
  final List<TopGame> topGames = [
    TopGame(
      name: 'Ludo Royale',
      hours: '${ludoHours.toStringAsFixed(1)}h',
      color: '#52B788',
    ),
    const TopGame(
      name: 'Cyber Arena',
      hours: '0.0h',
      color: '#40916C',
    ),
  ];

  // Campaign progress
  final List<Campaign> campaigns = [
    Campaign(
      name: 'Ludo Championship',
      progress: ludoPlayed > 0 ? (winRate.clamp(0, 100)) : 0,
      cover: '/gaming/armored_warrior.png',
    ),
  ];

  return GamingStats(
    totalHours: totalHoursStr,
    trend: trendStr,
    topGames: topGames,
    recentCampaigns: campaigns,
    activityHeatmap: heatmap,
    ludoPlayed: ludoPlayed,
    ludoWon: ludoWon,
    ludoMinutes: ludoMinutes,
  );
});
