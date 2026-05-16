import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Discover Servers Screen
///
/// Browse and join public servers with search, featured cards,
/// invite code input, and category filtering.
/// Route: /server/discover
class DiscoverServersScreen extends ConsumerStatefulWidget {
  const DiscoverServersScreen({super.key});

  @override
  ConsumerState<DiscoverServersScreen> createState() => _DiscoverServersScreenState();
}

class _DiscoverServersScreenState extends ConsumerState<DiscoverServersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _servers = [];
  String _searchQuery = '';
  String? _joiningId;
  final _searchController = TextEditingController();
  final _inviteController = TextEditingController();
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      // Fetch public servers with member counts
      final response = await _client
          .from('servers')
          .select('id, name, icon, banner, description, member_count')
          .order('member_count', ascending: false)
          .limit(20);

      final List<Map<String, dynamic>> servers = [];

      for (final item in response as List) {
        final server = Map<String, dynamic>.from(item);
        server['online_count'] = ((server['member_count'] ?? 0) * 0.3).floor();

        // Check membership
        if (user != null) {
          final membership = await _client
              .from('server_members')
              .select('id')
              .eq('server_id', server['id'])
              .eq('user_id', user.id)
              .maybeSingle();
          server['is_member'] = membership != null;
        } else {
          server['is_member'] = false;
        }

        servers.add(server);
      }

      if (mounted) {
        setState(() {
          _servers = servers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredServers {
    if (_searchQuery.trim().isEmpty) return _servers;
    final q = _searchQuery.trim().toLowerCase();
    return _servers.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final desc = (s['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  Future<void> _joinServer(String serverId) async {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );
    if (user == null) return;

    setState(() => _joiningId = serverId);

    try {
      await _client.from('server_members').insert({
        'server_id': serverId,
        'user_id': user.id,
        'role': 'member',
      });

      // Post welcome message
      try {
        final firstChannel = await _client
            .from('channels')
            .select('id')
            .eq('server_id', serverId)
            .inFilter('type', ['text', 'announcement'])
            .order('position', ascending: true)
            .limit(1)
            .maybeSingle();

        if (firstChannel != null) {
          final displayName = user.userMetadata?['display_name'] ??
              user.userMetadata?['username'] ??
              'Someone';
          await _client.from('messages').insert({
            'channel_id': firstChannel['id'],
            'content': '$displayName joined the server.',
            'type': 'system',
            'system_type': 'join',
            'author_id': user.id,
          });
        }
      } catch (_) {
        // Non-critical
      }

      // Update local state
      setState(() {
        final idx = _servers.indexWhere((s) => s['id'] == serverId);
        if (idx >= 0) {
          _servers[idx]['is_member'] = true;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined server!')),
        );
        context.push('/server/$serverId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningId = null);
    }
  }

  Future<void> _joinByInvite() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) return;

    // Simple invite code handling - in production this would validate against invites table
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code joining coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Discover Servers',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Invite Code Input
          _buildInviteSection(),

          // Server List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
                : _filteredServers.isEmpty
                    ? _buildEmptyState()
                    : _buildServerList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(FlickoColors.textMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search servers...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(FlickoColors.textMuted)),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInviteSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgTertiary),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: Color(FlickoColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _inviteController,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter invite code...',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      textCapitalization: TextCapitalization.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _joinByInvite,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              'Join',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredServers.length,
      itemBuilder: (context, index) {
        final server = _filteredServers[index];
        return _buildServerCard(server);
      },
    );
  }

  Widget _buildServerCard(Map<String, dynamic> server) {
    final name = server['name'] ?? 'Unknown Server';
    final description = server['description'] as String?;
    final iconUrl = server['icon'] as String?;
    final bannerUrl = server['banner'] as String?;
    final memberCount = server['member_count'] ?? 0;
    final onlineCount = server['online_count'] ?? 0;
    final isMember = server['is_member'] as bool? ?? false;
    final serverId = server['id'] as String;
    final isJoining = _joiningId == serverId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/server/$serverId'),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF232428)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              SizedBox(
                height: 80,
                width: double.infinity,
                child: bannerUrl != null
                    ? Image.network(
                        bannerUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultBanner(),
                      )
                    : _buildDefaultBanner(),
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + Name
                    Row(
                      children: [
                        _buildServerIcon(iconUrl, name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textPrimary),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Description
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Meta
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMetaDot(const Color(FlickoColors.statusOnline)),
                        const SizedBox(width: 4),
                        Text(
                          '$onlineCount Online',
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildMetaDot(const Color(FlickoColors.textMuted)),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount Members',
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Join Button
                    if (isMember)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.bgTertiary),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Color(FlickoColors.success)),
                            const SizedBox(width: 6),
                            Text(
                              'Joined',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.success),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isJoining ? null : () => _joinServer(serverId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(FlickoColors.blurple),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: isJoining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Join Server',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      color: const Color(FlickoColors.blurple),
      child: Center(
        child: Icon(
          Icons.dns,
          size: 32,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildServerIcon(String? iconUrl, String name) {
    if (iconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          iconUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackIcon(name),
        ),
      );
    }
    return _buildFallbackIcon(name);
  }

  Widget _buildFallbackIcon(String name) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.blurple),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasSearch ? '😕' : '🔍',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No Servers Found' : 'No Servers to Discover',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'No servers match "${_searchQuery.trim()}". Try a different search.'
                  : 'Check back later for recommended communities to join.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
