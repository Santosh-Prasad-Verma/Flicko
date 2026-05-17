import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/features/shared/presentation/widgets/brutalist_widgets.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

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

  static const Color lime = Color(0xFFCBEF17);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);

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

  String? _errorDetail;

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
      _errorDetail = null;
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
          _errorDetail = e.toString();
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
      await _client.from('server_members').insert({
        'server_id': serverId,
        'user_id': user.id,
        'role': 'member',
      });

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

      setState(() {
        final idx = _servers.indexWhere((s) => s['id'] == serverId);
        if (idx >= 0) {
          _servers[idx]['is_member'] = true;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('JOINED_SUCCESSFULLY'),
            backgroundColor: lime,
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
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadServers,
                color: lime,
                backgroundColor: black,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroHeader().animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 48),
                      _buildSearchBar().animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 48),
                      _buildTopicSection().animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 48),
                      _buildTrendingSpacesSection(),
                      const SizedBox(height: 48),
                      _buildTrendingMomentsSection(),
                      const SizedBox(height: 48),
                      const BrutalistLegalFooter(),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: black,
        border: Border(bottom: BorderSide(color: lime, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BrutalistIconButton(icon: Icons.arrow_back_ios_new, onTap: () => context.pop()),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                'DISCOVER.CORE',
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          BrutalistIconButton(icon: Icons.add_box_outlined, onTap: () => context.push('/server/create')),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Stack(
            children: [
              Text(
                'DISCOVER',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                  letterSpacing: -2,
                  color: lime,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 45),
                child: Text(
                  'SYSTEM',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                    letterSpacing: -2,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2
                      ..color = white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(width: 60, height: 8, color: lime),
        const SizedBox(height: 24),
        Text(
          'EXPLORE THE CORE COMMUNITIES AND NETWORK NODES. PROTOCOL: DISCOVERY_ACTIVE. SYSTEM STATUS: NOMINAL',
          style: GoogleFonts.robotoMono(
            color: white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: black,
        border: Border.all(color: white, width: 3),
        boxShadow: const [
          BoxShadow(color: white, offset: Offset(6, 6)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        onSubmitted: (v) {
          setState(() => _searchQuery = v);
          _loadServers();
        },
        style: GoogleFonts.robotoMono(color: white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: '> SEARCH_NETWORK_NODES...',
          hintStyle: GoogleFonts.robotoMono(color: white.withValues(alpha: 0.3)),
          prefixIcon: const Icon(Icons.terminal, color: lime, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildTopicSection() {
    final topics = ['ALL', 'GAMING', 'MUSIC', 'FASHION', 'ART', 'TECH', 'DESIGN'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.label_important, color: lime, size: 18),
            const SizedBox(width: 8),
            Text(
              'TOPIC_FILTER',
              style: GoogleFonts.robotoMono(
                color: white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: topics.map((t) {
              final isSelected = t == _selectedTopic;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTopic = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? lime : black,
                      border: Border.all(color: isSelected ? black : white, width: 3),
                      boxShadow: isSelected ? null : [const BoxShadow(color: lime, offset: Offset(4, 4))],
                    ),
                    child: Text(
                      t,
                      style: GoogleFonts.robotoMono(
                        color: isSelected ? black : white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'TRENDING_SPACES',
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            _brutalistTextButton('VIEW_ALL', () {}),
          ],
        ),
        const SizedBox(height: 32),
        if (_isLoading)
          _buildLoadingState()
        else if (_filteredServers.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredServers.length > 5 ? 5 : _filteredServers.length,
            itemBuilder: (context, index) => _buildBrutalistServerCard(_filteredServers[index], index == 0),
          ),
      ],
    );
  }

  Widget _buildBrutalistServerCard(Map<String, dynamic> server, bool isPremium) {
    final name = server['name'] ?? 'UNKNOWN_SPACE';
    final desc = server['description'] ?? 'NO_DESCRIPTION_AVAILABLE';
    final memberCount = server['member_count'] ?? 0;
    final isMember = server['is_member'] ?? false;
    final serverId = server['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: black,
        border: Border.all(color: isPremium ? lime : white, width: 3),
        boxShadow: [
          BoxShadow(color: isPremium ? lime : white.withValues(alpha: 0.1), offset: const Offset(8, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (server['banner'] != null)
            Stack(
              children: [
                Image.network(
                  server['banner'],
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [black.withValues(alpha: 0.4), Colors.transparent],
                    ),
                  ),
                ),
                if (isPremium)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const BoxDecoration(color: lime),
                      child: Text(
                        'FEATURED',
                        style: GoogleFonts.robotoMono(
                          color: black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          else
            Container(
              height: 100,
              width: double.infinity,
              color: grey,
              child: const Center(child: Icon(Icons.hub, color: white, size: 40)),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name.toString().toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          color: white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people_outline, color: lime, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${memberCount} NODES_ACTIVE',
                      style: GoogleFonts.robotoMono(
                        color: white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  desc.toString().toUpperCase(),
                  style: GoogleFonts.robotoMono(
                    color: white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 32),
                _brutalistButton(
                  text: isMember ? 'ACCESS_DENIED_ENTRY' : 'INITIALIZE_JOIN_PROTOCOL',
                  onTap: () {
                    if (isMember) {
                      context.push('/server/$serverId');
                    } else {
                      _joinServer(serverId);
                    }
                  },
                  color: isMember ? white : lime,
                  textColor: black,
                  isLoading: _joiningId == serverId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingMomentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'NETWORK_MOMENTS',
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            _brutalistTextButton('VIEW_ALL', () {}),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) => _buildMomentCard(index),
          ),
        ),
      ],
    );
  }

  Widget _buildMomentCard(int index) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 24, bottom: 12),
      decoration: BoxDecoration(
        color: black,
        border: Border.all(color: white, width: 3),
        boxShadow: const [
          BoxShadow(color: lime, offset: Offset(6, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: grey,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.play_circle_outline, color: white, size: 48),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red),
                      child: Text(
                        'LIVE',
                        style: GoogleFonts.robotoMono(
                          color: white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@NODE_${index + 101}',
                  style: GoogleFonts.robotoMono(
                    color: lime,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ACTIVE_STREAM',
                  style: GoogleFonts.robotoMono(
                    color: white.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brutalistButton({
    required String text,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: black, width: 3),
          boxShadow: [
            BoxShadow(
              color: color == lime ? white : lime,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 3, color: textColor),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: GoogleFonts.spaceGrotesk(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _brutalistTextButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: white, width: 2),
        ),
        child: Text(
          text,
          style: GoogleFonts.robotoMono(
            color: white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircularProgressIndicator(color: lime, strokeWidth: 4),
          const SizedBox(height: 24),
          Text(
            'SCANNING_NETWORK_NODES...',
            style: GoogleFonts.robotoMono(color: white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: white.withValues(alpha: 0.1), width: 3),
          color: grey,
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off, color: lime, size: 48),
            const SizedBox(height: 24),
            Text(
              'NO_RESULTS_FOUND',
              style: GoogleFonts.spaceGrotesk(color: white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'TRY_REDEFINING_SEARCH_PARAMETERS_OR_FILTER_TOPICS',
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                color: white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
