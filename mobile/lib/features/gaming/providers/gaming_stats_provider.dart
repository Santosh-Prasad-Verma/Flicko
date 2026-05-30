import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Model for Gaming Stats API response
class GamingStats {
  final String totalHours;
  final String trend;
  final List<TopGame> topGames;
  final List<Campaign> recentCampaigns;
  final List<int> activityHeatmap;

  const GamingStats({
    required this.totalHours,
    required this.trend,
    required this.topGames,
    required this.recentCampaigns,
    required this.activityHeatmap,
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
    );
  }

  /// Fallback static data used when the API is unreachable.
  factory GamingStats.fallback() => GamingStats(
        totalHours: '12,345h',
        trend: '+18%',
        topGames: const [
          TopGame(name: 'Ludo', hours: '3,120h', color: '#40916C'),
          TopGame(name: 'Chess', hours: '2,890h', color: '#10B981'),
          TopGame(name: 'Cyber Arena', hours: '1,740h', color: '#52B788'),
        ],
        recentCampaigns: const [
          Campaign(
              name: 'Cyber Ninja S4',
              progress: 78,
              cover: '/gaming/cyber_ninja.png'),
          Campaign(
              name: 'Ludo Championship',
              progress: 45,
              cover: '/gaming/armored_warrior.png'),
          Campaign(
              name: 'Star Wars',
              progress: 92,
              cover: '/gaming/sci_fi_pilot.png'),
        ],
        activityHeatmap: List.generate(60, (i) => (i * 7 + 3) % 4),
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

/// Riverpod FutureProvider that fetches gaming stats from the backend.
/// Falls back to static mock data if the API is unavailable.
final gamingStatsProvider = FutureProvider<GamingStats>((ref) async {
  try {
    // TODO: Replace with authenticated HTTP client from app DI
    final response = await http
        .get(Uri.parse('http://localhost:8080/api/v1/gaming/stats'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return GamingStats.fromJson(data);
    }
  } catch (_) {
    // Silently fall back to static data during development
  }
  return GamingStats.fallback();
});
