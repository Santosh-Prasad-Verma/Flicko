import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/models/auth_state.dart' as app_auth;

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

  final _serverIconSize = 48.0;
  final _activeIndicatorHeight = 36.0;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    
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
      setState(() => _isLoading = false);
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
      context.push('/server/$_selectedServerId/channel/$channelId/voice');
    } else {
      context.push('/server/$_selectedServerId/channel/$channelId');
    }
  }

  void _handleServerOptions() {
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
      context.push('/server/$_selectedServerId/settings');
    } else {
      context.push('/server/$_selectedServerId/server-options');
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
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(FlickoColors.blurple)),
          ),
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
            onTap: () => context.push('/dm'),
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
}
