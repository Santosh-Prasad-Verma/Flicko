import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/repositories/server_repository.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';

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
  String _selectedTopic = 'ALL';
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
    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      var query = _client.from('servers').select('id, name, icon, banner, description');

      if (_searchQuery.trim().isNotEmpty) {
        query = query.or('name.ilike.%${_searchQuery.trim()}%,description.ilike.%${_searchQuery.trim()}%');
      }

      final response = await query.limit(50);

      final List<Map<String, dynamic>> servers = [];

      for (final item in response as List) {
        final server = Map<String, dynamic>.from(item);

        try {
          final countResponse = await _client.from('server_members').select('id').eq('server_id', server['id']);
          server['member_count'] = (countResponse as List).length;
        } catch (_) {
          server['member_count'] = 0;
        }

        server['online_count'] = ((server['member_count'] as int) * 0.3).floor();

        if (user != null) {
          try {
            final membership = await _client
                .from('server_members')
                .select('id')
                .eq('server_id', server['id'])
                .eq('user_id', user.id)
                .maybeSingle();
            server['is_member'] = membership != null;
          } catch (_) {
            server['is_member'] = false;
          }
        } else {
          server['is_member'] = false;
        }

        servers.add(server);
      }

      servers.sort((a, b) => (b['member_count'] as int).compareTo(a['member_count'] as int));

      if (mounted) {
        setState(() {
          _servers = servers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Discover servers error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredServers {
    List<Map<String, dynamic>> filtered = _servers;

    if (_selectedTopic != 'ALL') {
      filtered = filtered.where((s) {
        final desc = (s['description'] ?? '').toString().toLowerCase();
        final name = (s['name'] ?? '').toString().toLowerCase();
        final topic = _selectedTopic.toLowerCase();
        return name.contains(topic) || desc.contains(topic);
      }).toList();
    }

    if (_searchQuery.trim().isEmpty) return filtered;

    final q = _searchQuery.trim().toLowerCase();
    return filtered.where((s) {
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
      await ref.read(serverRepositoryProvider).joinServer(serverId, user.id);

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
      } catch (_) {}

      await ref.read(serversNotifierProvider.notifier).refresh();

      setState(() {
        final idx = _servers.indexWhere((s) => s['id'] == serverId);
        if (idx >= 0) {
          _servers[idx]['is_member'] = true;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined server successfully!'),
            backgroundColor: Color(FlickoColors.brandLime),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadServers,
                color: const Color(FlickoColors.brandLime),
                backgroundColor: const Color(FlickoColors.bgSecondary),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroHeader().animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 28),
                      _buildSearchBar().animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0),
                      const SizedBox(height: 28),
                      _buildTopicSection().animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 32),
                      _buildTrendingSpacesSection(),
                      const SizedBox(height: 32),
                      _buildCleanFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          bottom: BorderSide(
            color: Color(FlickoColors.border),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(FlickoColors.textPrimary)),
            onPressed: () => context.pop(),
          ),
          Text(
            'Discover',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 24, color: Color(FlickoColors.brandLime)),
            onPressed: () => context.push('/server/create'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find your community',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: const Color(FlickoColors.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore servers and meet new people in gaming, music, art, technology, and more.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(FlickoColors.border), width: 1.5),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        onSubmitted: (v) {
          setState(() => _searchQuery = v);
          _loadServers();
        },
        style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        decoration: InputDecoration(
          hintText: 'Search for servers...',
          hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(FlickoColors.textSecondary), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTopicSection() {
    final topics = ['All', 'Gaming', 'Music', 'Fashion', 'Art', 'Tech', 'Design'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Topics',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: topics.map((t) {
              final isSelected = t.toUpperCase() == _selectedTopic;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTopic = t.toUpperCase()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(FlickoColors.brandLime) : const Color(FlickoColors.bgSecondary),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(FlickoColors.brandLime) : const Color(FlickoColors.border),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      t,
                      style: GoogleFonts.inter(
                        color: isSelected ? const Color(FlickoColors.black) : const Color(FlickoColors.textPrimary),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingSpacesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trending Servers',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          _buildLoadingState()
        else if (_filteredServers.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredServers.length > 5 ? 5 : _filteredServers.length,
            itemBuilder: (context, index) => _buildModernServerCard(_filteredServers[index]),
          ),
      ],
    );
  }

  Widget _buildModernServerCard(Map<String, dynamic> server) {
    final name = server['name'] ?? 'Unnamed Server';
    final desc = server['description'] ?? 'No description available.';
    final memberCount = server['member_count'] ?? 0;
    final isMember = server['is_member'] ?? false;
    final serverId = server['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(FlickoColors.border), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (server['banner'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                server['banner'],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 80,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(FlickoColors.bgTertiary),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, color: Color(FlickoColors.textMuted), size: 32),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(FlickoColors.bgTertiary),
                  backgroundImage: server['icon'] != null ? NetworkImage(server['icon']) : null,
                  child: server['icon'] == null
                      ? Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$memberCount members',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        desc,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isMember) {
                              context.go('/');
                            } else {
                              _joinServer(serverId);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMember ? const Color(FlickoColors.bgTertiary) : const Color(FlickoColors.brandLime),
                            foregroundColor: isMember ? const Color(FlickoColors.textPrimary) : const Color(FlickoColors.black),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            elevation: 0,
                          ),
                          child: _joiningId == serverId
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Text(
                                  isMember ? 'Go to Server' : 'Join Server',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildLoadingState() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) => const ServerSkeleton(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(FlickoColors.border), width: 1),
          color: const Color(FlickoColors.bgSecondary),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, color: Color(FlickoColors.textMuted), size: 48),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search query or choosing another topic.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Text(
          'Flicko Communities • Subject to Community Guidelines',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
