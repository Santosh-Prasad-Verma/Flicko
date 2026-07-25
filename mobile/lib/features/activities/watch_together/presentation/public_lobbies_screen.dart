import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:mobile/features/server_channels/voice/presentation/screens/watch_together_screen.dart';
import 'package:mobile/features/server_channels/voice/presentation/controllers/watch_together_controller.dart';

class PublicLobbiesScreen extends ConsumerStatefulWidget {
  const PublicLobbiesScreen({super.key});

  @override
  ConsumerState<PublicLobbiesScreen> createState() => _PublicLobbiesScreenState();
}

class _PublicLobbiesScreenState extends ConsumerState<PublicLobbiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _lobbies = [];
  List<dynamic> _filteredLobbies = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLobbies();
    _searchController.addListener(_filterLobbies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLobbies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/v1/wt/lobbies');
      final List<dynamic> data = response.data ?? [];
      
      setState(() {
        _lobbies = data;
        _filteredLobbies = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterLobbies() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredLobbies = _lobbies;
      });
      return;
    }

    setState(() {
      _filteredLobbies = _lobbies.where((lobby) {
        final lobbyName = (lobby['lobby_name'] as String? ?? '').toLowerCase();
        final mediaTitle = (lobby['media_title'] as String? ?? '').toLowerCase();
        final mediaUrl = (lobby['media_url'] as String? ?? '').toLowerCase();
        return lobbyName.contains(query) || mediaTitle.contains(query) || mediaUrl.contains(query);
      }).toList();
    });
  }

  Future<void> _joinLobby(String sessionId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Joining lobby $sessionId...')),
      );

      await ref.read(watchTogetherControllerProvider.notifier).joinSession(sessionId);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Joined successfully!'),
          backgroundColor: const Color(FlickoColors.success),
        ),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const WatchTogetherScreen(
              serverId: '',
              channelId: '',
            ),
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to join lobby: ${e.toString()}'),
          backgroundColor: const Color(FlickoColors.danger),
        ),
      );
    }
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
          'Public Lobbies',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w700,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x1F52B788),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(FlickoColors.brandLime)),
            onPressed: _fetchLobbies,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              const Color(FlickoColors.brandLime).withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search active lobbies or movies...',
                    hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(FlickoColors.textMuted)),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(FlickoColors.bgSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(FlickoColors.brandLime)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              // Lobby lists
              Expanded(
                child: RefreshIndicator(
                  color: const Color(FlickoColors.brandLime),
                  backgroundColor: const Color(FlickoColors.bgSecondary),
                  onRefresh: _fetchLobbies,
                  child: _buildMainContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(FlickoColors.brandLime)),
        ),
      );
    }

    if (_error != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(FlickoColors.danger), size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load lobbies',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.brandLime),
                  foregroundColor: Colors.black,
                ),
                onPressed: _fetchLobbies,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredLobbies.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgSecondary),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tv_off_rounded,
                  color: Color(FlickoColors.textMuted),
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Active Lobbies',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No lobbies match your search criteria.'
                    : 'Be the first one to create a public watch room and stream together!',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredLobbies.length,
      itemBuilder: (context, index) {
        final lobby = _filteredLobbies[index];
        return _buildLobbyCard(lobby);
      },
    );
  }

  Widget _buildLobbyCard(dynamic lobby) {
    final lobbyName = lobby['lobby_name'] as String? ?? 'Co-watching Session';
    final mediaTitle = lobby['media_title'] as String? ?? 'Streaming Video';
    final mediaKind = lobby['media_kind'] as String? ?? 'youtube';
    final mediaUrl = lobby['media_url'] as String? ?? '';
    final maxViewers = lobby['settings']?['max_viewers'] as int? ?? 12;
    final sessionId = lobby['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E1E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper details bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    mediaKind == 'youtube' ? Icons.play_circle_filled_rounded : Icons.movie_outlined,
                    color: const Color(FlickoColors.brandLime),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lobbyName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Media: $mediaTitle',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mediaUrl,
                        style: GoogleFonts.robotoMono(
                          color: const Color(FlickoColors.textMuted),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Color(0xFF1E1E1E), height: 1),

          // Action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: Color(FlickoColors.textSecondary), size: 12),
                          const SizedBox(width: 6),
                          Text(
                            'Max $maxViewers',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textSecondary),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        mediaKind.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.brandLime),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Join button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.brandLime),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _joinLobby(sessionId),
                  child: Text(
                    'Join Room',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
