import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await _client
          .from('bans')
          .select('''
            id,
            user_id,
            reason,
            created_at,
            banned_user:user_id(username, avatar_url:avatar, display_name),
            executor:banned_by(username, display_name)
          ''')
          .eq('server_id', widget.serverId)
          .order('created_at', ascending: false);

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading bans: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _unban(String banId, String userId) async {
    try {
      await _client.from('bans').delete().eq('id', banId);

      // Write audit log
      final authState = ref.read(authNotifierProvider);
      final currentUser =
          authState.maybeWhen(authenticated: (u, _) => u, orElse: () => null);

      if (currentUser != null) {
        final unbannedUser = _bans.firstWhere((b) => b.userId == userId);
        await _client.from('audit_log').insert({
          'server_id': widget.serverId,
          'actor_id': currentUser.id,
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
            backgroundColor: Color(0xFF52B788),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _confirmUnban(_Ban ban) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: Text(
          'UNBAN ${ban.username?.toUpperCase() ?? 'USER'}',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'This user will be able to rejoin the server with a new invite.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: GoogleFonts.inter(
                    color: Colors.white24, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unban(ban.id, ban.userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text('UNBAN',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
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
    return _bans.where((b) {
      return (b.username?.toLowerCase().contains(q) ?? false) ||
          (b.reason?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBans;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'BANNED USERS',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search bans...',
                  hintStyle:
                      GoogleFonts.inter(color: Colors.white24, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF52B788), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF52B788)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.gavel_rounded,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'NO RESULTS FOR "$_searchQuery"'
                                  : 'NO BANNED USERS',
                              style: GoogleFonts.inter(
                                color: Colors.white24,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBans,
                        color: const Color(0xFF52B788),
                        backgroundColor: const Color(0xFF0D0D0D),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ban.avatarUrl != null
                  ? Image.network(ban.avatarUrl!, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        (ban.username ?? '?')[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF52B788),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ban.username ?? 'Unknown User',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (ban.reason != null && ban.reason!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ban.reason!,
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 10, color: Colors.white24),
                    const SizedBox(width: 4),
                    Text(
                      'BY ${ban.executorName?.toUpperCase() ?? 'ADMIN'}',
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time_rounded,
                        size: 10, color: Colors.white24),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(ban.bannedAt).toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildSmallActionButton('UNBAN', () => _confirmUnban(ban),
              isDanger: true),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton(String label, VoidCallback onTap,
      {bool isDanger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDanger
              ? Colors.redAccent.withValues(alpha: 0.1)
              : const Color(0xFF52B788).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDanger
                ? Colors.redAccent.withValues(alpha: 0.2)
                : const Color(0xFF52B788).withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isDanger ? Colors.redAccent : const Color(0xFF52B788),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
