import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/models/auth_state.dart' as app_auth;
import 'package:mobile/features/voice/application/sonic_drip_notifier.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';
import 'package:mobile/features/shared/presentation/widgets/flicko_error_state.dart';

/// Feed/Home Screen — Discord Mobile Style
///
/// Shows a vertical list of server icons (left rail) with the main content
/// area showing the selected server's channels or the home/DMs view.
/// This matches Discord's mobile Servers tab exactly.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  String? _selectedServerId; // null = home view, string = serverId
  bool _isLoading = true;
  List<Map<String, dynamic>> _servers = [];
  List<Map<String, dynamic>> _channels = [];
  Object? _error;

  final _serverIconSize = 48.0;
  final _activeIndicatorHeight = 36.0;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final supabase = Supabase.instance.client;
      final authState = ref.read(authNotifierProvider);
      final user = authState.maybeWhen(
        authenticated: (authUser, _) => authUser,
        orElse: () => null,
      );
      
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final data = await supabase
          .from('server_members')
          .select('server:servers(*)')
          .eq('user_id', user.id);

      final servers = (data as List<dynamic>)
          .map((row) {
            final membership = row as Map<String, dynamic>;
            final server = membership['server'];
            if (server is List) return server.isNotEmpty ? server[0] : null;
            return server;
          })
          .where((s) => s != null)
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading servers: $e');
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChannels(String serverId) async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('channels')
          .select('*')
          .eq('server_id', serverId)
          .order('position', ascending: true);

      setState(() {
        _channels = (data as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading channels: $e');
    }
  }

  void _selectServer(String? serverId) {
    setState(() => _selectedServerId = serverId);
    if (serverId != null) {
      _loadChannels(serverId);
    } else {
      setState(() => _channels = []);
    }
  }

  void _handleChannelPress(String channelId, String channelType) {
    if (channelType == 'voice' || channelType == 'stage') {
      // Join voice channel in the background — the floating VoiceHUD appears
      // automatically. Users can tap the HUD to navigate to the full voice screen.
      ref.read(voiceControllerProvider.notifier).joinChannel(channelId, _selectedServerId ?? '');
    } else {
      context.push('/server/$_selectedServerId/channel/$channelId');
    }
  }

  Future<void> _handleServerOptions() async {
    if (_selectedServerId == null) return;
    
    final selectedServer = _servers.firstWhere(
      (s) => s['id'] == _selectedServerId,
      orElse: () => {},
    );
    
    final authState = ref.read(authNotifierProvider);
    final user = authState.maybeWhen(
      authenticated: (authUser, _) => authUser,
      orElse: () => null,
    );
    final isOwner = selectedServer['owner_id'] == user?.id;
    
    if (isOwner) {
      await context.push('/server/$_selectedServerId/settings');
    } else {
      await context.push('/server/$_selectedServerId/server-options');
    }

    // Reload channels when returning from settings (user may have created/edited/deleted channels)
    if (_selectedServerId != null) {
      _loadChannels(_selectedServerId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(
      authenticated: (authUser, _) => authUser,
      orElse: () => null,
    );
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(FlickoColors.bgTertiary),
        body: SafeArea(child: FeedSkeleton()),
      );
    }

    if (_error != null && _servers.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgTertiary),
        body: FlickoErrorState.fromException(
          _error!,
          onRetry: _loadServers,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgTertiary),
      body: Row(
        children: [
          // Left Server Rail
          _buildServerRail(),
          
          // Main Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                ),
              ),
              child: _selectedServerId == null
                  ? _buildHomeView(user)
                  : _buildServerView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerRail() {
    final isHomeActive = _selectedServerId == null;

    return Container(
      width: 72,
      color: const Color(FlickoColors.bgTertiary),
      child: Column(
        children: [
          const SizedBox(height: 8),
          
          // Home button with Flicko logo
          _buildRailButton(
            isActive: isHomeActive,
            onTap: () => _selectServer(null),
            child: Container(
              width: _serverIconSize,
              height: _serverIconSize,
              decoration: BoxDecoration(
                color: isHomeActive
                    ? const Color(FlickoColors.blurple)
                    : const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(isHomeActive ? 16 : _serverIconSize / 2),
              ),
              child: const Icon(
                Icons.chat_bubble,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          // Messages / DMs button
          _buildRailButton(
            isActive: false,
            onTap: () => context.go('/dms'),
            child: Container(
              width: _serverIconSize,
              height: _serverIconSize,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(_serverIconSize / 2),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Color(FlickoColors.textPrimary),
                size: 22,
              ),
            ),
          ),
          
          // Divider
          Container(
            width: 32,
            height: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgTertiary),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          
          // Server icons - scrollable
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _servers.length + 2, // +2 for add and discover buttons
              itemBuilder: (context, index) {
                if (index < _servers.length) {
                  return _buildServerIcon(_servers[index]);
                } else if (index == _servers.length) {
                  // Add server button
                  return _buildRailButton(
                    isActive: false,
                    onTap: () => context.push('/server/create'),
                    child: Container(
                      width: _serverIconSize,
                      height: _serverIconSize,
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        borderRadius: BorderRadius.circular(_serverIconSize / 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Color(FlickoColors.green),
                        size: 28,
                      ),
                    ),
                  );
                } else {
                  // Discover button
                  return _buildRailButton(
                    isActive: false,
                    onTap: () => context.push('/server/discover'),
                    child: Container(
                      width: _serverIconSize,
                      height: _serverIconSize,
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        borderRadius: BorderRadius.circular(_serverIconSize / 2),
                      ),
                      child: const Icon(
                        Icons.explore,
                        color: Color(FlickoColors.green),
                        size: 24,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailButton({
    required bool isActive,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 64,
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Active pill indicator
            Container(
              width: 4,
              height: isActive ? _activeIndicatorHeight : 0,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
            // Icon container
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildServerIcon(Map<String, dynamic> server) {
    final isActive = _selectedServerId == server['id'];
    final serverIcon = server['icon'] as String?;
    final serverName = server['name'] as String? ?? 'Server';

    return GestureDetector(
      onTap: () => _selectServer(server['id']),
      onLongPress: () => context.push('/server/${server['id']}'),
      child: Container(
        width: 72,
        height: 64,
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Active pill indicator
            Container(
              width: 4,
              height: isActive ? _activeIndicatorHeight : 0,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
            // Server icon
            Container(
              width: _serverIconSize,
              height: _serverIconSize,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(FlickoColors.blurple)
                    : const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(isActive ? 16 : _serverIconSize / 2),
                image: serverIcon != null
                    ? DecorationImage(
                        image: NetworkImage(serverIcon),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: serverIcon == null
                  ? Center(
                      child: Text(
                        serverName
                            .split(' ')
                            .map((w) => w.isNotEmpty ? w[0] : '')
                            .join('')
                            .toUpperCase()
                            .substring(0, serverName.split(' ').length > 1 ? 2 : 1),
                        style: GoogleFonts.inter(
                          color: isActive
                              ? Colors.white
                              : const Color(FlickoColors.textPrimary),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView(User? user) {
    final dripState = ref.watch(sonicDripProvider);
    final hasActiveTrack = dripState.playback.currentTrack != null;

    return Column(
      children: [
        // Header
        _buildHeader(
          title: 'Flicko',
          subtitle: 'Welcome back, ${user?.userMetadata?['username'] ?? 'User'}',
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Color(FlickoColors.textSecondary)),
              onPressed: () => context.push('/search'),
            ),
          ],
        ),
        
        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Welcome Card
              _buildWelcomeCard(),
              
              if (hasActiveTrack) ...[
                const SizedBox(height: 24),
                _buildNowPlayingPanel(dripState),
              ],
              
              const SizedBox(height: 24),
              
              // Your Servers heading
              if (_servers.isNotEmpty) ...[
                Text(
                  'YOUR SERVERS',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ..._servers.map((server) => _buildServerRow(server)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerView() {
    final selectedServer = _servers.firstWhere(
      (s) => s['id'] == _selectedServerId,
      orElse: () => {},
    );
    
    final authState = ref.read(authNotifierProvider);
    final user = authState.maybeWhen(
      authenticated: (authUser, _) => authUser,
      orElse: () => null,
    );
    final isOwner = selectedServer['owner_id'] == user?.id;

    return Column(
      children: [
        // Header
        _buildHeader(
          title: selectedServer['name'] ?? 'Server',
          actions: [
            IconButton(
              icon: const Icon(Icons.people, color: Color(FlickoColors.textSecondary)),
              onPressed: () => context.push('/server/$_selectedServerId/members'),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(FlickoColors.textSecondary)),
              onPressed: _handleServerOptions,
            ),
          ],
        ),
        
        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Server Banner
              if (selectedServer['banner'] != null)
                Container(
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(selectedServer['banner']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              
              // Channels
              ..._channels.map((channel) => _buildChannelRow(channel)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required String title,
    String? subtitle,
    List<Widget>? actions,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          if (actions != null) ...actions,
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.blurple),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Flicko',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect with friends, join communities, and explore servers',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerRow(Map<String, dynamic> server) {
    final serverIcon = server['icon'] as String?;
    final serverName = server['name'] as String? ?? 'Server';
    final description = server['description'] as String?;

    return InkWell(
      onTap: () => _selectServer(server['id']),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgPrimary),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // Server icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: serverIcon == null
                    ? const Color(FlickoColors.blurple)
                    : null,
                borderRadius: BorderRadius.circular(12),
                image: serverIcon != null
                    ? DecorationImage(
                        image: NetworkImage(serverIcon),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: serverIcon == null
                  ? Center(
                      child: Text(
                        serverName[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // Server info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serverName,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            const Icon(
              Icons.chevron_right,
              color: Color(FlickoColors.textMuted),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelRow(Map<String, dynamic> channel) {
    final channelType = channel['type'] as String? ?? 'text';
    final channelName = channel['name'] as String? ?? 'channel';
    final isCategory = channelType == 'category';

    if (isCategory) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
        child: Row(
          children: [
            const Icon(
              Icons.expand_more,
              color: Color(FlickoColors.textMuted),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              channelName.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    IconData channelIcon;
    switch (channelType) {
      case 'voice':
        channelIcon = Icons.volume_up;
        break;
      case 'announcement':
        channelIcon = Icons.campaign_outlined;
        break;
      case 'forum':
        channelIcon = Icons.forum_outlined;
        break;
      default:
        channelIcon = Icons.chat_bubble_outline;
    }

    return InkWell(
      onTap: () => _handleChannelPress(channel['id'], channelType),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Icon(
              channelIcon,
              color: const Color(FlickoColors.textMuted),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              channelName,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingPanel(SonicDripState dripState) {
    final currentTrack = dripState.playback.currentTrack;
    if (currentTrack == null) return const SizedBox.shrink();

    final isPlaying = dripState.isPlaying;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        border: Border.all(color: const Color(0xFF52B788), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF52B788),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radio_rounded, color: Color(0xFF52B788), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'NOW PLAYING // SONIC DRIP',
                    style: GoogleFonts.spaceMono(
                      color: const Color(0xFF52B788),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPlaying ? const Color(0xFF52B788) : const Color(0xFF71717A),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  isPlaying ? 'LIVE' : 'PAUSED',
                  style: GoogleFonts.spaceMono(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Track Info & Visualizer Animation Row
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFF71717A).withValues(alpha: 0.3), width: 1),
                ),
                child: currentTrack.imageUrl != null && currentTrack.imageUrl!.isNotEmpty
                    ? Image.network(
                        currentTrack.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFF52B788),
                          size: 24,
                        ),
                      )
                    : const Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFF52B788),
                        size: 24,
                      ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack.name.toUpperCase(),
                      style: GoogleFonts.epilogue(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack.artistName.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: const Color(0xFF71717A),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              _EqualizerWave(isPlaying: isPlaying),
            ],
          ),
          const SizedBox(height: 16),

          // Timeline Progress Bar
          Row(
            children: [
              Text(
                dripState.playback.positionFormatted,
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF71717A),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: const Color(0xFF52B788),
                    inactiveTrackColor: const Color(0xFF1F1F23),
                    thumbColor: const Color(0xFF52B788),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayColor: const Color(0xFF52B788).withValues(alpha: 0.1),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: dripState.playback.progress,
                    onChanged: (val) {
                      ref.read(sonicDripProvider.notifier).seekTo(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dripState.playback.durationFormatted,
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFF71717A),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildControlBtn(
                icon: Icons.skip_previous_rounded,
                onTap: () => ref.read(sonicDripProvider.notifier).skipPrevious(),
              ),
              
              GestureDetector(
                onTap: () => ref.read(sonicDripProvider.notifier).togglePlayPause(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPlaying ? Colors.transparent : const Color(0xFF52B788),
                    border: Border.all(color: const Color(0xFF52B788), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: isPlaying ? const Color(0xFF52B788) : Colors.black,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPlaying ? 'PAUSE' : 'PLAY',
                        style: GoogleFonts.spaceMono(
                          color: isPlaying ? const Color(0xFF52B788) : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _buildControlBtn(
                icon: Icons.skip_next_rounded,
                onTap: () => ref.read(sonicDripProvider.notifier).skipNext(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: const Color(0xFF71717A).withValues(alpha: 0.3), width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _EqualizerWave extends StatefulWidget {
  final bool isPlaying;

  const _EqualizerWave({required this.isPlaying});

  @override
  State<_EqualizerWave> createState() => _EqualizerWaveState();
}

class _EqualizerWaveState extends State<_EqualizerWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _EqualizerWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (index) {
              double val = _controller.value;
              double heightFactor = 0.2;
              if (widget.isPlaying) {
                final offset = index * 0.4;
                final angle = (val * 2 * math.pi) + offset;
                heightFactor = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(angle)).clamp(0.0, 1.0);
              }
              return Container(
                width: 4,
                height: 36 * heightFactor,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF52B788),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
