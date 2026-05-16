import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Bans Screen
///
/// Lists banned members with unban functionality.
/// Connected to Supabase `server_bans` table with `profiles` join.
class BansScreen extends ConsumerStatefulWidget {
  final String serverId;
  const BansScreen({super.key, required this.serverId});

  @override
  ConsumerState<BansScreen> createState() => _BansScreenState();
}

class _Ban {
  final String id;
  final String userId;
  final String? username;
  final String? avatarUrl;
  final String? reason;
  final String? executorName;
  final DateTime? bannedAt;

  _Ban({
    required this.id,
    required this.userId,
    this.username,
    this.avatarUrl,
    this.reason,
    this.executorName,
    this.bannedAt,
  });
}

class _BansScreenState extends ConsumerState<BansScreen> {
  bool _isLoading = true;
  List<_Ban> _bans = [];
  String _searchQuery = '';
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadBans();
  }

  Future<void> _loadBans() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('server_bans')
          .select('''
            id,
            user_id,
            reason,
            created_at,
            banned_user:user_id(username, avatar_url, display_name),
            executor:executor_id(username, display_name)
          ''')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      setState(() {
        _bans = (response as List).map((row) {
          final user = row['banned_user'] as Map<String, dynamic>?;
          final executor = row['executor'] as Map<String, dynamic>?;
          return _Ban(
            id: row['id'] as String? ?? '',
            userId: row['user_id'] as String,
            username: user?['display_name'] ?? user?['username'],
            avatarUrl: user?['avatar_url'],
            reason: row['reason'],
            executorName: executor?['display_name'] ?? executor?['username'],
            bannedAt: row['created_at'] != null
                ? DateTime.tryParse(row['created_at'])
                : null,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bans: $e')),
        );
      }
    }
  }

  Future<void> _unban(String banId, String userId) async {
    try {
      await _client.from('server_bans').delete().eq('id', banId);

      // Write audit log
      final actorId = _client.auth.currentUser?.id;
      if (actorId != null) {
        final unbannedUser = _bans.firstWhere((b) => b.userId == userId);
        await _client.from('audit_logs').insert({
          'server_id': widget.serverId,
          'actor_id': actorId,
          'action_type': 'member_unban',
          'target_type': 'member',
          'target_id': userId,
          'changes': {
            'username': unbannedUser.username,
          },
        });
      }

      setState(() => _bans.removeWhere((b) => b.userId == userId));
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User unbanned'),
            backgroundColor: Color(FlickoColors.green),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _confirmUnban(_Ban ban) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlickoRadius.lg),
        ),
        title: Text(
          'Unban ${ban.username ?? 'User'}?',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This user will be able to rejoin the server with a new invite.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unban(ban.id, ban.userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.danger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FlickoRadius.md)),
            ),
            child: Text('Unban', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 30) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  List<_Ban> get _filteredBans {
    if (_searchQuery.isEmpty) return _bans;
    final q = _searchQuery.toLowerCase();
    return _bans.where((b) =>
      (b.username?.toLowerCase().contains(q) ?? false) ||
      (b.reason?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBans;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Bans (${_bans.length})',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(FlickoColors.bgSecondary),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search banned members...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted), size: 20),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // ── Ban list ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.gavel_outlined,
                              size: 48,
                              color: const Color(FlickoColors.textMuted),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No bans matching "$_searchQuery"'
                                  : 'No banned members',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textMuted),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBans,
                        color: const Color(FlickoColors.blurple),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final ban = filtered[index];
                            return _buildBanTile(ban);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanTile(_Ban ban) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(FlickoRadius.lg),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(FlickoColors.bgTertiary),
            backgroundImage: ban.avatarUrl != null ? NetworkImage(ban.avatarUrl!) : null,
            child: ban.avatarUrl == null
                ? Text(
                    (ban.username ?? '?')[0].toUpperCase(),
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Name + reason + metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ban.username ?? 'Unknown User',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ban.reason != null && ban.reason!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ban.reason!,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (ban.executorName != null) ...[
                      Icon(Icons.person_outline, size: 12, color: const Color(FlickoColors.textMuted).withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        'by ${ban.executorName}',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted).withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (ban.bannedAt != null) ...[
                      if (ban.executorName != null) const SizedBox(width: 8),
                      Icon(Icons.access_time, size: 12, color: const Color(FlickoColors.textMuted).withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        _formatDate(ban.bannedAt),
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted).withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Unban button
          TextButton(
            onPressed: () => _confirmUnban(ban),
            style: TextButton.styleFrom(
              backgroundColor: const Color(FlickoColors.danger).withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FlickoRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              'Unban',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.danger),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
