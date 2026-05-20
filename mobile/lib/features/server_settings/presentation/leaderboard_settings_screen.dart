import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class LeaderboardSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const LeaderboardSettingsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<LeaderboardSettingsScreen> createState() => _LeaderboardSettingsScreenState();
}

class _LeaderboardSettingsScreenState extends ConsumerState<LeaderboardSettingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('level_settings')
          .select('*, profiles(username, display_name, avatar_url:avatar)')
          .eq('server_id', widget.serverId)
          .order('xp', ascending: false)
          .limit(50);

      setState(() {
        _leaderboard = (response as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Leaderboard',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text('Error loading leaderboard', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadLeaderboard, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text('No leaderboard data', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text('Enable leveling to see the leaderboard', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaderboard.length,
        itemBuilder: (context, index) => _buildLeaderboardItem(_leaderboard[index], index),
      ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> item, int index) {
    final profile = item['profiles'] as Map<String, dynamic>?;
    final username = profile?['username'] ?? 'Unknown';
    final displayName = profile?['display_name'] ?? username;
    final avatarUrl = profile?['avatar_url'];
    final xp = item['xp'] as int? ?? 0;
    final level = item['level'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildRankBadge(index),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    username[0].toUpperCase(),
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(FlickoColors.blurple)),
                    const SizedBox(width: 4),
                    Text(
                      'Level $level',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$xp XP',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int index) {
    Color badgeColor;
    IconData icon;

    if (index == 0) {
      badgeColor = const Color(0xFFFFD700);
      icon = Icons.emoji_events;
    } else if (index == 1) {
      badgeColor = const Color(0xFFC0C0C0);
      icon = Icons.emoji_events;
    } else if (index == 2) {
      badgeColor = const Color(0xFFCD7F32);
      icon = Icons.emoji_events;
    } else {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(FlickoColors.bgTertiary),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
